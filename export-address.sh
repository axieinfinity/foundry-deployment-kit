index=0
# Define the deployments folder by concatenating it with the child folder
root="deployments/"

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
                    echo "$contractName@$contractAddress" >>"$folder"/exported_address
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
