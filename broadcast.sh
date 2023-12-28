# Source (or "dot") the .env file to load environment variables
if [ -f .env ]; then
    source .broadcast.env
else
    echo "Error: .broadcast.env file not found."
fi

verify_arg=""
extra_argument=""

for arg in "$@"; do
    case $arg in
    --trezor)
        extra_argument+=trezor@
        ;;
    *) ;;
    esac
done

# Remove the @ character from the end of extra_argument
extra_argument="${extra_argument%%@}"

echo Broadcast Tx...
echo From: ${FROM}
echo To: ${TO}
echo Value: ${VALUE}
echo GasAmount: ${GAS}
echo Calldata:
cast pretty-calldata ${CALLDATA}
calldata=$(cast calldata 'broadcast(address,address,uint256,uint256,bytes)' ${FROM} ${TO} ${GAS} ${VALUE} ${CALLDATA})
forge script ${verify_arg} ${@} -g 200 OnchainExecutor --sig 'run(bytes,string)' ${calldata} "${extra_argument}"