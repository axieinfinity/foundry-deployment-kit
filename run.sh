# Function to display script usage
usage() {
    forge script --help

    echo ""
    echo "\033[33mFoundry Script Usage:\033[0m"
    echo "Usage: $0 [forge_options] --no-postcheck|--npo --no-precheck|--npr --sender {sender_address} --force-generate-artifact"
    echo "Options:"
    echo " --no-postcheck: Disable post-check"
    echo " --no-precheck: Disable pre-check"
    echo " --sender: Specify the default sender address"
    echo " --force-generate-artifact: Force generate artifact"

    exit 1
}

# Check if command-line arguments are provided
if [ "$#" -eq 0 ]; then
    usage
fi

verify_arg=""
extra_argument=""

index=0
op_command=""
network_name=""
is_broadcast=false
should_verify=false
force_generate_artifact=false
# Define the deployments folder by concatenating it with the child folder
root="deployments/"

export_address() {
    index=0

    start_time=$(date +%s)

    for folder in "$root"/*; do
        # If exported_address.toml exists, delete it
        if [ -f "$folder"/exported_address ]; then
            rm "$folder"/exported_address
        fi

        # Create a new exported_address file
        touch "$folder"/exported_address

        for file in "$folder"/*.json; do

            # Check if the file exists and is a regular file
            if [ -f "$file" ] && [ "$(basename "$file")" != ".chainId" ] && [ "$(basename "$file")" != "exported_address" ]; then
                ((index++))
                (
                    # Extract address from the JSON file
                    contractAddress=$(jq -r '.address' "$file")
                    # Extract contractName from file name without the extension
                    contractName=$(basename "$file" .json)

                    # Check if contractName and address are not empty
                    if [ -n "$contractName" ]; then
                        # Write to file the contractName and address
                        echo "$contractName.json@$contractAddress" >>"$folder"/exported_address
                    else
                        echo "Error: Missing contractName or address in $file"
                    fi
                ) &
            fi

            # Check if index is a multiple of 10, then wait
            if [ $((index % 10)) -eq 0 ]; then
                wait
            fi
        done
    done

    wait

    end_time=$(date +%s)
    echo "Export address in deployment folder: $((end_time - start_time)) seconds"
}

index=0

for arg in "$@"; do
    case $arg in
    -t | --trezor)
        extra_argument+=trezor@
        ;;
    --np | --no-postcheck)
        set -- "${@/#--no-postcheck/}"
        extra_argument+=no-postcheck@
        ;;
    --npr | --no-precheck)
        set -- "${@/#--no-precheck/}"
        extra_argument+=no-precheck@
        ;;
    --verify)
        should_verify=true
        set -- "${@/#--verify/}"
        ;;
    -f | --fork-url)
        network_name=${@:index+2:1}
        # skip if network_name is localhost
        if [[ $network_name != "localhost" ]]; then
            extra_argument+="network.${network_name}@"

            set -- "${@/#-f/}"
            set -- "${@/#--fork-url/}"
            set -- "${@/#$network_name/}"
        fi

        ;;
    --fork-block-number)
        fork_block_number=${@:index+2:1}
        extra_argument+="fork-block-number.${fork_block_number}@"

        set -- "${@/#--fork-block-number/}"
        set -- "${@/#$fork_block_number/}"
        ;;
    --broadcast)
        is_broadcast=true
        ;;
    --sender)
        sender=${@:index+2:1}
        extra_argument+="sender.${sender}@"
        ;;
    --force-generate-artifact)
        force_generate_artifact=true

        set -- "${@/#--force-generate-artifact/}"
        ;;
    -h | --help)
        usage
        exist 1
        ;;
    *) ;;
    esac
    index=$((index + 1))
done

export_address

echo "\033[33mTrying to compile contracts ...\033[0m"
forge build # Ensure the contracts are compiled before running the script

should_verify=$([[ $should_verify == true && $is_broadcast == true ]] && echo true || echo false)

if [[ $force_generate_artifact == true ]]; then
    extra_argument+=generate-artifact@
fi

if [[ $should_verify == true ]] && [[ $force_generate_artifact == false ]]; then
    extra_argument+=generate-artifact@
fi

if [[ $should_verify == true ]] && [[ ! $network_name == "ronin-mainnet" ]] && [[ ! $network_name == "ronin-testnet" ]]; then
    verify_arg="--verify --retries 5"
fi

echo "Should Verify Contract: $should_verify"

# Remove the @ character from the end of extra_argument
extra_argument="${extra_argument%%@}"

## Check if the private key is stored in the .env file
if [[ ! $extra_argument == *"sender"* ]] && [[ ! $extra_argument == *"trezor"* ]]; then
    # Check if the .env file exists
    if [ -f .env ]; then
        source .env
        # If network_name is empty, set it to localhost
        network_name=${network_name:-localhost}
        # Convert network name to uppercase
        account_label=$(echo $network_name | tr '[:lower:]' '[:upper:]')
        # Replace "-" with "_"
        account_label=$(echo $account_label | tr '-' '_')
        # Add "_PK" prefix
        account_label="${account_label}_PK"

        # Check if the private key is stored in the .env file
        if [[ $(eval "echo \$$account_label") == *"op://"* ]]; then
            echo "\033[32mFound 'op://' in ${account_label}\033[0m"
            op_command="op run --env-file="./.env" --"
        elif [[ $(eval "echo \$$account_label") == *""* ]]; then
            echo "\033[33mWARNING: Not found private key in ${account_label}\033[0m"
        fi
    else
        echo "\033[33mWARNING: .env file not found\033[0m"
    fi

fi

start_time=$(date +%s)

${op_command} forge script ${verify_arg} ${@} -g 200 --sig 'run(bytes,string)' $(cast calldata 'run()') "${extra_argument}"

# Check if the command was successful
if [ $? -eq 0 ]; then
    if [[ $should_verify == true ]]; then
        if [[ $network_name == "ronin-mainnet" ]] || [[ $network_name == "ronin-testnet" ]]; then
            echo "Verifying contract..."
            # Remove .env content
            env_data=$(cat .env)
            >.env

            while IFS=',' read -r deployed; do
                yarn hardhat sourcify --endpoint https://sourcify.roninchain.com/server --network ${network_name} --contract-name $deployed
            done <./logs/deployed-contracts

            # Restore the .env content
            echo $env_data >.env
        fi
    fi
fi

end_time=$(date +%s)

# Remove the deployed-contracts file
rm -rf ./logs/deployed-contracts
echo "Execution time: $((end_time - start_time))s"
