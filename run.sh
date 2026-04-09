#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"

usage() {
    echo "Usage: $0 <script_path> [forge_options...]"
    echo ""
    echo "Examples:"
    echo "  $0 script/sample/SampleDeploy.s.sol -f ronin-testnet --broadcast --verify"
    echo "  $0 script/sample/SampleDeploy.s.sol --rpc-url ronin-testnet --broadcast"
    echo ""
    echo "Custom flags (non-forge):"
    echo "  --call <sig>   Inner function signature (default: run())"
    exit 1
}

# ---------------------------------------------------------------------------
# Post-broadcast: record deployed addresses from broadcast JSON
# ---------------------------------------------------------------------------

resolve_script_key() {
    local rel="$1"
    rel="${rel#./}"
    [[ "$rel" == "$script_dir/"* ]] && rel="${rel#"$script_dir/"}"
    [[ "$rel" == script/* ]] && rel="${rel#script/}"
    echo "${rel//\//_}"
}

find_latest_broadcast_file() {
    local dir="$script_dir/broadcast/$1"
    [ ! -d "$dir" ] && return 1
    local files=()
    shopt -s nullglob; files=("$dir"/*/run-latest.json); shopt -u nullglob
    [ "${#files[@]}" -eq 0 ] && return 1
    ls -t "${files[@]}" | head -n 1
}

resolve_network_from_chain_id() {
    case "$1" in
        2020)   echo "ronin-mainnet" ;;
        202601) echo "ronin-testnet" ;;
        *)      echo "localhost" ;;
    esac
}

extract_chain_id() {
    python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('chain',''))" "$1"
}

extract_deployment_lines() {
    python3 - "$1" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
seen, out = set(), []
for tx in data.get("transactions", []):
    if tx.get("transactionType") != "CREATE": continue
    n, a = tx.get("contractName"), tx.get("contractAddress")
    if n and a:
        line = f"{n}.json@{a}"
        if line not in seen: seen.add(line); out.append(line)
print("\n".join(out))
PY
}

record_broadcast_deployments() {
    local script_path="$1" net="$2"
    local key bf
    key="$(resolve_script_key "$script_path")"
    bf="$(find_latest_broadcast_file "$key")" || return 0
    [ -z "$net" ] && net="$(resolve_network_from_chain_id "$(extract_chain_id "$bf")")"
    local lines; lines="$(extract_deployment_lines "$bf")"
    [ -z "$lines" ] && return 0
    local dir="$script_dir/deployments/$net" ef="$script_dir/deployments/$net/exported_address"
    mkdir -p "$dir"; [ ! -f "$ef" ] && : > "$ef"
    while IFS= read -r l; do
        [ -z "$l" ] && continue
        grep -qxF "$l" "$ef" || echo "$l" >> "$ef"
    done <<< "$lines"
}

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------

[ "$#" -eq 0 ] && usage

script_path="$1"; shift

network=""
is_broadcast=false
should_verify=false
has_sender=false
call_sig="run()"

# Scan args: extract info we need, build cleaned arg list
cleaned=()
args=("$@")
i=0
while [ "$i" -lt "${#args[@]}" ]; do
    arg="${args[$i]}"
    case "$arg" in
    -f|--fork-url|--rpc-url)
        network="${args[$((i+1))]}"
        cleaned+=("$arg" "$network")
        i=$((i + 2)); continue ;;
    --broadcast)
        is_broadcast=true
        cleaned+=("$arg") ;;
    --verify)
        should_verify=true ;;  # stripped; re-added with network-aware args
    --sender)
        has_sender=true
        cleaned+=("$arg") ;;
    --call)
        call_sig="${args[$((i+1))]}"
        i=$((i + 2)); continue ;;
    -h|--help)
        usage ;;
    *)
        cleaned+=("$arg") ;;
    esac
    i=$((i + 1))
done

# Build command string for ScriptExtended
command=""
[ -n "$network" ] && [ "$network" != "localhost" ] && command="network.${network}"

# Only verify when also broadcasting (matches original behaviour)
should_verify=$([[ "$should_verify" == true && "$is_broadcast" == true ]] && echo true || echo false)

# ---------------------------------------------------------------------------
# 1Password op:// detection  (mirrors mainnet/run.sh)
# ---------------------------------------------------------------------------

op_command=""

if [ "$has_sender" = false ]; then
    if [ -f "${script_dir}/.env" ]; then
        source "${script_dir}/.env"

        network_for_pk="${network:-localhost}"
        account_label=$(echo "$network_for_pk" | tr '[:lower:]' '[:upper:]' | tr '-' '_')_PK
        pk_value="$(eval "echo \${$account_label:-}")"

        if [[ "$pk_value" == *"op://"* ]]; then
            echo -e "\033[32mFound 'op://' in ${account_label}\033[0m"
            op_command="op run --env-file=${script_dir}/.env --"
        elif [[ -z "$pk_value" ]]; then
            echo -e "\033[33mWARNING: Not found private key in ${account_label}\033[0m"
        fi
    else
        echo -e "\033[33mWARNING: .env file not found\033[0m"
    fi
fi

# ---------------------------------------------------------------------------
# Build & execute
# ---------------------------------------------------------------------------

verify_args=""
if [ "$should_verify" = true ]; then
    case "$network" in
    ronin-mainnet) verify_args="--verify --retries 5 --verifier sourcify --chain 2020" ;;
    ronin-testnet) verify_args="--verify --retries 5 --verifier blockscout --verifier-url https://explorer-saigon-testnet-cc58e966ql.t.conduit.xyz/api" ;;
    *)             verify_args="--verify --retries 5" ;;
    esac
fi

call_data=$(cast calldata "$call_sig")

echo "Should Verify Contract: $should_verify"

start_time=$(date +%s)

# shellcheck disable=SC2086
${op_command} forge script "$script_path" \
    ${verify_args} \
    "${cleaned[@]+"${cleaned[@]}"}" \
    --sig "run(bytes,string)" "$call_data" "$command"

if [ $? -ne 0 ]; then exit 1; fi

end_time=$(date +%s)
echo "Execution time: $((end_time - start_time))s"

if [ "$is_broadcast" = true ]; then
    record_broadcast_deployments "$script_path" "$network"
fi
