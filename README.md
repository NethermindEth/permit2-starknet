# Permit2 on Starknet

Cairo implementation of Uniswap Labs's Permit2 contract. Original codebase [here](https://github.com/Uniswap/permit2).

## Run Tests

### Requirements

- [scarb = 2.10.1](https://docs.swmansion.com/scarb/)
- [starknet-foundry> = 0.38.3](https://foundry-rs.github.io/starknet-foundry/getting-started/installation.html)

From the root directory, run:

```bash
scarb test
```

## Deploy Contract

A modular Go package for deployment is available in the [`go/`](./go/) directory.

**Requirements:**

- [Go 1.21+](https://golang.org/dl/)

**Setup:**

1. **Build the contracts** (if not already built):

   ```bash
   scarb build && cd go
   ```

2. Install dependencies:

   ```bash
   go mod tidy
   ```

3. Copy environment template and configure:

   ```bash
   cp env.example .env
   # Edit .env with your account details
   ```

**Run deployment:**

```bash
go run main.go
```

**Alternative:** Use the convenience script:

```bash
./deploy.sh
```

The deployment details will be saved to `LATEST_DEPLOYMENT.md`.

**Package Structure:**

- `deployment/` - Core deployment logic
- `examples/` - Usage examples (coming soon)
- `main.go` - Main deployment script
