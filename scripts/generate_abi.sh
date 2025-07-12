#!/bin/bash

# Add contracts here as "contract_name:abi_name"
contracts=(
	"Permit2:permit2"
)

echo "Running scarb build..."
cd .. && scarb build

# Generate ABIs
for contract in "${contracts[@]}"; do
	IFS=':' read -r contract_name abi_name <<<"$contract"
	json_file="./target/dev/permit2_${contract_name}.contract_class.json"
	abi_file="./abi/${abi_name}.ts"

	npx abi-wan-kanabi --input "$json_file" --output "$abi_file"
done
