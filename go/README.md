# Permit2 Contract Deployment

A streamlined Go script for deploying the Permit2 contract on Starknet.

## Features

- **Smart Declaration**: Automatically handles already-declared contracts
- **UDC Deployment**: Uses Universal Deployer Contract for deployment
- **Auto Class Hash**: Extracts class hash from contract files when needed
- **Clean Output**: Saves deployment details to `LATEST_DEPLOYMENT.md`

## Prerequisites

- [Go 1.21+](https://golang.org/dl/)
- Built contract in `../target/dev/`
- Funded Starknet account

## Quick Start

1. **Build the contracts** (if not already built):
   ```bash
   cd .. && scarb build && cd go
   ```

2. **Install dependencies:**
   ```bash
   go mod tidy
   ```

3. **Configure environment:**
   ```bash
   cp env.example .env
   # Edit .env with your account details
   ```

4. **Run deployment:**
   ```bash
   go run main.go
   ```

   **Or use the convenience script:**
   ```bash
   ./deploy.sh
   ```

## What It Does

1. **Declaration**: Attempts to declare the contract, handles already-declared gracefully
2. **Deployment**: Deploys using UDC with no constructor arguments
3. **Documentation**: Saves deployment info to `LATEST_DEPLOYMENT.md`

## Convenience Script

The `deploy.sh` script automatically:
- Checks Go installation and contract files
- Installs dependencies with `go mod tidy`
- Runs the deployment
- Provides helpful error messages for common issues

## Environment Variables

**Required:**
- `STARKNET_DEPLOYER_ADDRESS`: Your account address
- `STARKNET_DEPLOYER_PRIVATE_KEY`: Your private key
- `STARKNET_DEPLOYER_PUBLIC_KEY`: Your public key

**Optional:**
- `RPC_URL`: RPC endpoint (defaults to Sepolia)

## Output

- **`LATEST_DEPLOYMENT.md`**: Deployment details in markdown format

## Network

- **Default**: Starknet Sepolia
- **RPC**: `https://starknet-sepolia.public.blastapi.io`

## Contract

- **Name**: Permit2
- **Constructor**: None
- **Method**: UDC deployment
