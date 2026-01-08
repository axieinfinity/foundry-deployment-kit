#!/bin/bash

# Parse the command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
    --name)
        name="$2"
        shift
        ;;
    --args)
        args="$2"
        shift
        ;;
    --value)
        value="$2"
        shift
        ;;
    --nonce)
        nonce="$2"
        shift
        ;;
    --address)
        address="$2"
        shift
        ;;
    --deployer)
        deployer="$2"
        shift
        ;;
    --chainid)
        chainid="$2"
        shift
        ;;
    --block-number)
        block_number="$2"
        shift
        ;;
    --timestamp)
        timestamp="$2"
        shift
        ;;
    --absolute-path)
        absolute_path="$2"
        shift
        ;;
    --path)
        path="$2"
        shift
        ;;
    --artifact-name)
        artifact_name="$2"
        shift
        ;;
    *)
        echo "Unknown parameter passed: $1"
        exit 1
        ;;
    esac
    shift
done

if [[ -z "$name" || -z "$args" || -z "$value" || -z "$nonce" || -z "$deployer" || -z "$chainid" || -z "$block-number" || -z "$timestamp" || -z "$absolute_path" || -z "$path" ]]; then
    echo "Error: Missing required arguments."
    echo "Usage: ./generate-artifact.sh --name <name> --value <value> --nonce <nonce> --address <address> --deployer <deployer> --chainid <chainid> --block-number <block_number> --timestamp <timestamp> --absolute-path <absolute_path> --args <args> --path <path> --artifact-name <artifact_name>"
    exit 1
fi

source_name=$(basename $absolute_path)
# Remove .json or .sol extension
source_name=${source_name%.*}
#
echo "source_name: $source_name"

# Generate the artifact
abi=$(forge inspect $source_name abi --json)
devdoc=$(forge inspect $source_name devdoc --json)
userdoc=$(forge inspect $source_name userdoc --json)
metadata=$(forge inspect $source_name metadata --json)
storage_layout=$(forge inspect $source_name storageLayout --json)
bytecode=$(forge inspect $source_name bytecode)
deployed_bytecode=$(forge inspect $source_name deployedBytecode)

sanitize_json_field() {
    local name="$1"
    local value="$2"

    if [[ -z "$value" || "$value" == "null" ]]; then
        echo "field $name is null" >&2
        echo "null"
        return
    fi

    # Ensure the value is valid JSON; fallback to null if not
    if echo "$value" | jq -c . >/dev/null 2>&1; then
        echo "$value" | jq -c .
    else
        echo "field $name is invalid JSON; defaulting to null" >&2
        echo "null"
    fi
}

sanitize_string_field() {
    local name="$1"
    local value="$2"

    if [[ -z "$value" || "$value" == "null" ]]; then
        echo "field $name is null" >&2
        echo ""
    else
        echo "$value"
    fi
}

abi=$(sanitize_json_field "abi" "$abi")
devdoc=$(sanitize_json_field "devdoc" "$devdoc")
userdoc=$(sanitize_json_field "userdoc" "$userdoc")
metadata=$(sanitize_json_field "metadata" "$metadata")
storage_layout=$(sanitize_json_field "storage_layout" "$storage_layout")
bytecode=$(sanitize_string_field "bytecode" "$bytecode")
deployed_bytecode=$(sanitize_string_field "deployed_bytecode" "$deployed_bytecode")

# Create the JSON object
json_content=$(
    jq -n \
        --arg name "$name" \
        --arg address "$address" \
        --arg args "$args" \
        --arg value "$value" \
        --arg nonce "$nonce" \
        --arg deployer "$deployer" \
        --arg chainid "$chainid" \
        --arg block_number "$block_number" \
        --arg timestamp "$timestamp" \
        --argjson abi "$abi" \
        --argjson devdoc "$devdoc" \
        --argjson userdoc "$userdoc" \
        --argjson metadata "$metadata" \
        --argjson storage_layout "$storage_layout" \
        --arg bytecode "$bytecode" \
        --arg deployed_bytecode "$deployed_bytecode" \
        '{
        name: $name,
        address: $address,
        args: $args,
        value: $value,
        nonce: $nonce,
        deployer: $deployer,
        chainid: $chainid,
        block_number: $block_number,
        timestamp: $timestamp,
        abi: $abi,
        devdoc: $devdoc,
        userdoc: $userdoc,
        metadata: $metadata,
        storage_layout: $storage_layout,
        bytecode: $bytecode,
        deployed_bytecode: $deployed_bytecode
    }'
)

# Write the JSON object to the specified path
echo "$json_content" >"$path/$artifact_name.json"

# Write the JSON object to the specified path
echo "$json_content" >"$path/$artifact_name.json"
