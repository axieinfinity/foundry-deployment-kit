#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <script_path> [--network <alias>] [--command <string>] [--call <sig>] [--] [forge_args...]"
    echo ""
    echo "This is a thin wrapper over run.sh that adds -vvvv for verbose output."
    exit 1
}

if [ "$#" -eq 0 ]; then
    usage
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
args=("$@")
split_index=-1

for i in "${!args[@]}"; do
    if [ "${args[$i]}" = "--" ]; then
        split_index=$i
        break
    fi
done

if [ "$split_index" -ge 0 ]; then
    run_args=("${args[@]:0:$split_index}")
    forge_args=("${args[@]:$((split_index + 1))}")
else
    run_args=("${args[@]}")
    forge_args=()
fi

has_verbose=false
for arg in "${forge_args[@]}"; do
    if [[ "$arg" =~ ^-v+$ ]]; then
        has_verbose=true
        break
    fi
done

if [ "$has_verbose" = false ]; then
    forge_args+=("-vvvv")
fi

"$script_dir/run.sh" "${run_args[@]}" -- "${forge_args[@]}"
