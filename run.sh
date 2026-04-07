#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <script_path> [--network <alias>] [--command <string>] [--call <sig>] [--verify] [--] [forge_args...]"
    echo ""
    echo "Examples:"
    echo "  $0 script/examples/ExampleDeploySample.s.sol --network ronin-testnet -- --rpc-url <url>"
    echo "  $0 script/examples/ExampleDeploySample.s.sol --command network.ronin-testnet -- --rpc-url <url>"
    echo ""
    echo "Notes:"
    echo "  - --network only sets ScriptExtended's network selection."
    echo "  - Use -- to pass through forge flags (e.g. --broadcast, --rpc-url)."
    echo "  - --verify uses network-aware verifier defaults for ronin networks."
    exit 1
}

if [ "$#" -eq 0 ]; then
    usage
fi

script_path=""
network=""
command=""
call_sig="run()"
forge_args=()
verify=false

while [ "$#" -gt 0 ]; do
    case "$1" in
    --network)
        network="$2"
        shift 2
        ;;
    --command)
        command="$2"
        shift 2
        ;;
    --call)
        call_sig="$2"
        shift 2
        ;;
    --verify)
        verify=true
        shift
        ;;
    -h | --help)
        usage
        ;;
    --)
        shift
        forge_args+=("$@")
        break
        ;;
    *)
        if [ -z "$script_path" ]; then
            script_path="$1"
        else
            forge_args+=("$1")
        fi
        shift
        ;;
    esac
done

if [ -z "$script_path" ]; then
    usage
fi

if [ -z "$command" ] && [ -n "$network" ]; then
    command="network.${network}"
fi

if [ -z "$network" ] && [ -n "$command" ]; then
    case "$command" in
    network.*)
        network="${command#network.}"
        ;;
    network=*)
        network="${command#network=}"
        ;;
    esac
fi

verify_args=()
if [ "$verify" = true ]; then
    if [ "$network" = "ronin-mainnet" ]; then
        verify_args=(--verify --retries 5 --verifier sourcify --chain 2020)
    elif [ "$network" = "ronin-testnet" ]; then
        verify_args=(--verify --retries 5 --verifier blockscout --verifier-url https://explorer-saigon-testnet-cc58e966ql.t.conduit.xyz/api)
    else
        verify_args=(--verify --retries 5)
    fi
fi

call_data=$(cast calldata "$call_sig")

forge script "$script_path" "${verify_args[@]}" "${forge_args[@]}" --sig "run(bytes,string)" "$call_data" "$command"