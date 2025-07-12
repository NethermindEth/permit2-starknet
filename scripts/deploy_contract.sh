#!/bin/bash

# Ensure the script stops on the first error
set -e

# Load environment variables from .env file
if [ -f .env ]; then
	export $(grep -v '^#' .env | xargs)
else
	echo ".env file not found. Please create one based on env.example."
	exit 1
fi

# Check required environment variables
if [ -z "$STARKNET_RPC" ] || [ -z "$STARKNET_ACCOUNT" ] || [ -z "$STARKNET_PRIVATE_KEY" ]; then
	echo "ERROR - One or more required environment variables are missing."
	exit 1
fi

# Set environment for starkli
export STARKNET_RPC
export STARKNET_ACCOUNT
export STARKNET_PRIVATE_KEY

echo Starknet RPC: $STARKNET_RPC
echo Starknet Account: $STARKNET_ACCOUNT
echo Starknet Private Key: $STARKNET_PRIVATE_KEY

# Paths
CONTRACT_NAME="Permit2"
CONTRACT_JSON="../target/dev/permit2_${CONTRACT_NAME}.contract_class.json"

# Declare contract
echo
echo "=========================="
echo "Declare $CONTRACT_NAME"
echo "=========================="
echo
CLASS_HASH=$(starkli declare "$CONTRACT_JSON" --watch | grep -o '0x[a-fA-F0-9]\{64\}' | head -1)
echo "[$CONTRACT_NAME] Class hash declared: $CLASS_HASH"

# Deploy contract
echo
echo "=========================="
echo "Deploy $CONTRACT_NAME"
echo "=========================="
echo
CONTRACT_ADDRESS=$(starkli deploy "$CLASS_HASH" --watch | grep -o '0x[a-fA-F0-9]\{64\}' | head -1)
echo "[$CONTRACT_NAME] Contract deployed at: $CONTRACT_ADDRESS"

echo "$CONTRACT_NAME address: $CONTRACT_ADDRESS" >permit2_address.env
echo "Deployment address saved to permit2_address.env: $CONTRACT_ADDRESS"
