#!/usr/bin/env bash
set -euo pipefail

networkName="ronin-testnet"

usage() {
    echo "Usage: $0 -c <network>"
    echo "  -c: Specify the network (ronin-testnet or ronin-mainnet)"
    exit 1
}

while getopts "c:" opt; do
    case $opt in
    c)
        case "$OPTARG" in
        ronin-testnet)
            child_folder="ronin-testnet"
            networkName="ronin-testnet"
            ;;
        ronin-mainnet)
            child_folder="ronin-mainnet"
            networkName="ronin-mainnet"
            ;;
        *)
            echo "Unknown network specified: $OPTARG"
            usage
            ;;
        esac
        ;;
    *)
        usage
        ;;
    esac
done

shift $((OPTIND - 1))

folder="deployments/$child_folder"
exported="$folder/exported_address"

if [ ! -d "$folder" ]; then
    echo "Error: The specified folder does not exist for the selected network."
    exit 1
fi

if [ ! -f "$exported" ]; then
    echo "Error: $exported not found. Run a deployment script first."
    exit 1
fi

json_keys() {
    python3 - <<'PY'
import json, sys
data = json.loads(sys.stdin.read() or "{}")
for key in data.keys():
    print(key)
PY
}

index=0
while IFS= read -r line; do
    if [ -z "$line" ]; then
        continue
    fi

    contractName="${line%@*}"
    contractName="${contractName%.json}"
    if [ -z "$contractName" ]; then
        continue
    fi

    ((index++))
    (
        events=$(forge inspect "$contractName" events)
        errors=$(forge inspect "$contractName" errors)

        events_keys=()
        errors_keys=()

        while read -r key; do
            [ -n "$key" ] && events_keys+=("event $key")
        done <<<"$(echo "$events" | json_keys)"

        while read -r key; do
            [ -n "$key" ] && errors_keys+=("$key")
        done <<<"$(echo "$errors" | json_keys)"

        all_keys=("${events_keys[@]}" "${errors_keys[@]}")
        echo cast upload-signature "${all_keys[@]}"
        cast upload-signature "${all_keys[@]}"
    ) &

    if [ $((index % 10)) -eq 0 ]; then
        wait
    fi
done < "$exported"

forge selectors upload --all &

wait
