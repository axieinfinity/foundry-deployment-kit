verify_arg=""
extra_argument=""

index=0
network_name=""
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
        extra_argument+=generate-artifact@

        set -- "${@/#--verify/}"
        ;;
    -f | --fork-url)
        network_name=${@:index+2:1}
        extra_argument+="network.${network_name}@@"

        set -- "${@/#-f/}"
        set -- "${@/#--fork-url/}"
        set -- "${@/#$network_name/}"
        ;;
    --fork-block-number)
        fork_block_number=${@:index+2:1}
        extra_argument+=fork-block-number.${fork_block_number}@@

        set -- "${@/#--fork-block-number/}"
        set -- "${@/#$fork_block_number/}"
        ;;
    *) ;;
    esac
    index=$((index + 1))
done

# Remove the @ character from the end of extra_argument
extra_argument="${extra_argument%%@}"

op_command=""

## Check if the private key is stored in the .env file
if [[ ! $extra_argument == *"sender"* ]] && [[ ! $extra_argument == *"trezor"* ]]; then
    source .env

    if [[ $MAINNET_PK == op* ]] || [[ $TESTNET_PK == op* ]] || [[ $LOCAL_PK == op* ]]; then
        op_command="op run --env-file="./.env" --"
    fi
fi

if [[ $should_verify ]] && [[ ! $network_name == "ronin-mainnet" ]] && [[ ! $network_name == "ronin-testnet" ]] && [[ ! $network_name == "ronin-devnet" ]]; then
    verify_arg="--verify"
fi

calldata=$(cast calldata 'run()')
start_time=$(date +%s)

echo ${op_command} forge script ${verify_arg} ${@} -g 200 --sig 'run(bytes,string)' ${calldata} "${extra_argument}"
${op_command} forge script ${verify_arg} ${@} -g 200 --sig 'run(bytes,string)' ${calldata} "${extra_argument}"

end_time=$(date +%s)

echo "Execution time: $((end_time - start_time))s"
