# Permit2 on Starknet

Cairo implementation of Uniswap Labs's Permit2 contract. Original codebase [here](https://github.com/Uniswap/permit2).

## Run Tests

### Requirements

- [scarb](https://docs.swmansion.com/scarb/)

From the root directory, run:

```bash scarb test

```

## Deploy

### Requirements

- [starkli](https://github.com/xJonathanLEI/starkli)

### Setup

1. Move to the [scripts/](./scripts/) directory.

```bash
cd scripts
```

2. Copy [`.env.example`](./.env.example) to `.env` and fill in the required values.

3) Copy [`deployer_account.example.json`](./scripts/accounts/deployer_account.example.json) to `deployer_account.json` and fill in your account values.

### Run the script:

```bash
bash deploy_contract.sh
```

The latest deployment address and class hash will be saved to [`latest_deployment.txt`](./scripts/latest_deployment.txt).

## Generate ABI

### Requirements

- [scarb](https://docs.swmansion.com/scarb/)
- [abi-wan-kanabi](https://www.npmjs.com/package/abi-wan-kanabi)

### Generate ABI (for Typescript)

From the script directory, run:

```bash
bash generate_abi.sh
```

The generated ABI will be saved to [`permit2.ts`](./abi/permit2.ts).
