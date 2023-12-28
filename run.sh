verify_arg=""
extra_argument=""

for arg in "$@"; do
    case $arg in
    --trezor)
        extra_argument+=trezor@
        ;;
    --log)
        set -- "${@/#--log/}"
        extra_argument+=log@
        ;;
    *) ;;
    esac
done

# Remove the @ character from the end of extra_argument
extra_argument="${extra_argument%%@}"

calldata=$(cast calldata 'run()')
forge script ${verify_arg} ${@} -g 200 --sig 'run(bytes,string)' ${calldata} "${extra_argument}"
