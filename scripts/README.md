# Scripts

## Deployment

### Requirements

- [starkli (0.4.1)](https://github.com/xJonathanLEI/starkli)

## `deploy_contract.sh`

### Setup

0. Move to this directory.

```bash
cd scripts
```

2. Copy [`.env.example`](./.env.example) to `.env` and fill in the required values.

3) Copy [`deployer_account.katana.json`](./accounts/deployer_account.katana.json) to `deployer_account.json` and fill in your account values.

### Run the script:

```bash
bash deploy_contract.sh
```

The latest deployment address and class hash will be saved to [`latest_deployment.txt`](./latest_deployment.txt).
