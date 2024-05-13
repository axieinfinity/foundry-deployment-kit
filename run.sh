verify_arg=""
extra_argument=""

index=0
op_command=""
network_name=""
is_broadcast=false
should_verify=false

for arg in "$@"; do
    case $arg in
    --trezor)
        extra_argument+=trezor@
        ;;
    --no-postcheck)
        set -- "${@/#--no-postcheck/}"
        extra_argument+=no-postcheck@
        ;;
    --verify)
        should_verify=true
        set -- "${@/#--verify/}"
        ;;
    -f | --fork-url)
        network_name=${@:index+2:1}
        extra_argument+="network.${network_name}@"

        set -- "${@/#-f/}"
        set -- "${@/#--fork-url/}"
        set -- "${@/#$network_name/}"
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
    *) ;;
    esac
    index=$((index + 1))
done

should_verify=$([[ $should_verify == true && $is_broadcast == true ]] && echo true || echo false)

if [[ $should_verify == true ]]; then
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
    source .env

    if [[ $MAINNET_PK == op* ]] || [[ $TESTNET_PK == op* ]] || [[ $LOCAL_PK == op* ]]; then
        op_command="op run --env-file="./.env" --"
    fi
fi

calldata=$(cast calldata 'run()')
start_time=$(date +%s)

echo ${op_command} forge script ${verify_arg} ${@} -g 200 --sig 'run(bytes,string)' ${calldata} "${extra_argument}"
${op_command} forge script ${verify_arg} ${@} -g 200 --sig 'run(bytes,string)' ${calldata} "${extra_argument}"

if [[ $should_verify == true ]]; then
    if [[ $network_name == "ronin-mainnet" ]] || [[ $network_name == "ronin-testnet" ]]; then
        echo "Verifying contract..."
        yarn hardhat sourcify --endpoint https://sourcify.roninchain.com/server --network ${network_name}
    fi
fi

end_time=$(date +%s)

echo "Execution time: $((end_time - start_time))s"
