# Source (or "dot") the .env file to load environment variables
if [ -f .env ]; then
    source .debug.env
else
    echo "Error: .debug.env file not found."
fi

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

echo Debug Tx...
echo From: ${FROM}
echo To: ${TO}
echo Value: ${VALUE}
echo GasAmount: ${GAS}
echo Calldata:
cast pretty-calldata ${CALLDATA}
calldata=$(cast calldata 'trace(uint256,address,address,uint256,uint256,bytes)' ${BLOCK} ${FROM} ${TO} ${GAS} ${VALUE} ${CALLDATA})
forge script ${verify_arg} --legacy ${@} OnchainExecutor --sig 'run(bytes,string)' ${calldata} "${extra_argument}"
