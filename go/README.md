# Permit2 Go Package

A modular Go package for Permit2 contract operations on Starknet.

## Package Structure

```
go/
├── deployment/          # Contract deployment package
├── examples/            # Usage examples (coming soon)
├── main.go             # Main deployment script
├── deploy.sh           # Convenience script
└── README.md           # This file
```

## Features

- **Modular Design**: Clean separation of concerns
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

## Extending the Package

### Adding New Examples

1. Create new files in the `examples/` directory
2. Import the deployment package: `"github.com/NethermindEth/oif-starknet/go/deployment"`
3. Use the `Deployer` struct for contract operations

### Adding New Features

1. Create new packages in the root `go/` directory
2. Follow the same modular structure
3. Update this README with new functionality
