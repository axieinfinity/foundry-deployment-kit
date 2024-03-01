verify_arg=""
extra_argument=""

for arg in "$@"; do
    case $arg in
    --trezor)
        extra_argument+=trezor@
        ;;
    --disable-postcheck)
        set -- "${@/#--disable-postcheck/}"
        extra_argument+=no-postcheck@
        ;;
    --generate-artifacts)
        set -- "${@/#--generate-artifacts/}"
        extra_argument+=generate-artifact@
        ;;
    -atf)
        set -- "${@/#-atf/}"
        extra_argument+=generate-artifact@
        ;;
    *) ;;
    esac
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

calldata=$(cast calldata 'run()')
${op_command} forge script ${verify_arg} ${@} -g 200 --sig 'run(bytes,string)' ${calldata} "${extra_argument}"