package main

import (
	"context"
	"fmt"
	"math/big"
	"os"
	"strings"
	"time"

	"github.com/NethermindEth/juno/core/felt"
	"github.com/NethermindEth/starknet.go/account"
	"github.com/NethermindEth/starknet.go/contracts"
	"github.com/NethermindEth/starknet.go/hash"
	"github.com/NethermindEth/starknet.go/rpc"
	"github.com/NethermindEth/starknet.go/utils"
	"github.com/joho/godotenv"
)

const (
	// Contract file paths relative to the go/ directory
	sierraContractFilePath = "../target/dev/permit2_Permit2.contract_class.json"
	casmContractFilePath   = "../target/dev/permit2_Permit2.compiled_contract_class.json"
	
	// Network configuration
	networkName = "Starknet"
)

// DeploymentInfo represents the deployment information
type DeploymentInfo struct {
	DeployerAddress    string `json:"deployer_address"`
	DeploymentTxHash   string `json:"deployment_tx_hash"`
	ClassHash          string `json:"class_hash"`
	DeployedAddress    string `json:"deployed_address"`
	DeploymentTime     string `json:"deployment_time"`
}

func main() {
	if err := godotenv.Load(); err != nil {
		fmt.Println("⚠️  No .env file found, using environment variables")
	}

	fmt.Println("🚀 Permit2 Contract Deployment Script")
	fmt.Println("=====================================")

	// Load environment variables
	accountAddress := os.Getenv("STARKNET_DEPLOYER_ADDRESS")
	accountPrivateKey := os.Getenv("STARKNET_DEPLOYER_PRIVATE_KEY")
	accountPublicKey := os.Getenv("STARKNET_DEPLOYER_PUBLIC_KEY")

	if accountAddress == "" || accountPrivateKey == "" || accountPublicKey == "" {
		fmt.Println("❌ Missing required environment variables:")
		fmt.Println("   STARKNET_DEPLOYER_ADDRESS: Your Starknet account address")
		fmt.Println("   STARKNET_DEPLOYER_PRIVATE_KEY: Your private key")
		fmt.Println("   STARKNET_DEPLOYER_PUBLIC_KEY: Your public key")
		os.Exit(1)
	}

	// Get network configuration from environment
	rpcURL := os.Getenv("RPC_URL")
	if rpcURL == "" {
		rpcURL = "https://starknet-sepolia.public.blastapi.io" // default fallback
	}

	fmt.Printf("📋 Network: %s\n", networkName)
	fmt.Printf("📋 RPC URL: %s\n", rpcURL)
	fmt.Printf("📋 Account: %s\n", accountAddress)

	// Initialize connection to RPC provider
	client, err := rpc.NewProvider(rpcURL)
	if err != nil {
		panic(fmt.Sprintf("❌ Error connecting to RPC provider: %s", err))
	}

	// Initialize the account memkeyStore
	ks := account.NewMemKeystore()
	privKeyBI, ok := new(big.Int).SetString(accountPrivateKey, 0)
	if !ok {
		panic("❌ Failed to convert private key to big.Int")
	}
	ks.Put(accountPublicKey, privKeyBI)

	// Convert account address to felt
	accountAddressInFelt, err := utils.HexToFelt(accountAddress)
	if err != nil {
		fmt.Println("❌ Failed to transform the account address, did you give the hex address?")
		panic(err)
	}

	// Initialize the account
	accnt, err := account.NewAccount(client, accountAddressInFelt, accountPublicKey, ks, account.CairoV2)
	if err != nil {
		panic(fmt.Sprintf("❌ Failed to initialize account: %s", err))
	}

	fmt.Println("✅ Connected to Starknet RPC")

	// Step 1: Declare the contract
	fmt.Println("\n📋 Step 1: Declaring Permit2 contract...")
	classHash, err := declareContract(accnt)
	if err != nil {
		panic(fmt.Sprintf("❌ Declaration failed: %s", err))
	}
	fmt.Printf("✅ Contract declaration completed! Class Hash: %s\n", classHash)

	// Step 2: Deploy the contract
	fmt.Println("\n📋 Step 2: Deploying Permit2 contract...")
	deployedAddress, txHash, err := deployContract(accnt, classHash)
	if err != nil {
		panic(fmt.Sprintf("❌ Deployment failed: %s", err))
	}

	fmt.Printf("✅ Contract deployed successfully!\n")
	fmt.Printf("   Deployed Address: %s\n", deployedAddress)
	fmt.Printf("   Transaction Hash: %s\n", txHash)

	// Step 3: Save deployment information
	fmt.Println("\n📋 Step 3: Saving deployment information...")
	if err := saveDeploymentInfo(accountAddress, txHash, classHash, deployedAddress); err != nil {
		fmt.Printf("⚠️  Failed to save deployment info: %s\n", err)
	} else {
		fmt.Println("✅ Deployment information saved to LATEST_DEPLOYMENT.md")
	}

	fmt.Println("\n🎉 Permit2 deployment completed successfully!")
}

// declareContract declares the Permit2 contract
func declareContract(accnt *account.Account) (string, error) {
	fmt.Printf("📋 Loading contract files:\n")
	fmt.Printf("   Sierra: %s\n", sierraContractFilePath)
	fmt.Printf("   Casm: %s\n", casmContractFilePath)

	// Check if contract files exist
	if _, err := os.Stat(sierraContractFilePath); os.IsNotExist(err) {
		return "", fmt.Errorf("sierra contract file not found: %s", sierraContractFilePath)
	}
	if _, err := os.Stat(casmContractFilePath); os.IsNotExist(err) {
		return "", fmt.Errorf("casm contract file not found: %s", casmContractFilePath)
	}

	// Unmarshalling the casm contract class from a JSON file
	casmClass, err := utils.UnmarshalJSONFileToType[contracts.CasmClass](casmContractFilePath, "")
	if err != nil {
		return "", fmt.Errorf("failed to parse casm contract: %s", err)
	}

	// Unmarshalling the sierra contract class from a JSON file
	contractClass, err := utils.UnmarshalJSONFileToType[contracts.ContractClass](sierraContractFilePath, "")
	if err != nil {
		return "", fmt.Errorf("failed to parse sierra contract: %s", err)
	}

	// Building and sending the declare transaction
	fmt.Println("📤 Declaring contract...")
	resp, err := accnt.BuildAndSendDeclareTxn(
		context.Background(),
		casmClass,
		contractClass,
		nil,
	)
	if err != nil {
		// Check if it's an "already declared" error
		if strings.Contains(err.Error(), "already declared") {
			fmt.Println("✅ Contract already declared, extracting class hash...")
			// For already declared contracts, we need to get the class hash from the contract class
			// Use the proper ClassHash function from the hash package
			classHash := hash.ClassHash(contractClass)
			return classHash.String(), nil
		}
		return "", err
	}

	// Wait for transaction receipt
	fmt.Println("⏳ Waiting for declaration confirmation...")
	_, err = accnt.WaitForTransactionReceipt(context.Background(), resp.Hash, time.Second)
	if err != nil {
		return "", fmt.Errorf("declare transaction failed: %s", err)
	}

	return resp.ClassHash.String(), nil
}

// deployContract deploys the Permit2 contract
func deployContract(accnt *account.Account, classHash string) (string, string, error) {
	// Convert class hash to felt
	classHashFelt, err := utils.HexToFelt(classHash)
	if err != nil {
		return "", "", fmt.Errorf("invalid class hash: %s", err)
	}

	// Permit2 has no constructor arguments, so we pass empty calldata
	var constructorCalldata []*felt.Felt

	fmt.Println("📤 Sending deployment transaction...")

	// Deploy the contract with UDC
	resp, salt, err := accnt.DeployContractWithUDC(context.Background(), classHashFelt, constructorCalldata, nil, nil)
	if err != nil {
		return "", "", fmt.Errorf("failed to deploy contract: %s", err)
	}

	// Extract transaction hash from response
	txHash := resp.Hash
	fmt.Printf("⏳ Transaction sent! Hash: %s\n", txHash.String())
	fmt.Println("⏳ Waiting for transaction confirmation...")

	// Wait for transaction receipt
	txReceipt, err := accnt.WaitForTransactionReceipt(context.Background(), txHash, time.Second)
	if err != nil {
		return "", "", fmt.Errorf("failed to get transaction receipt: %s", err)
	}

	fmt.Printf("✅ Transaction confirmed!\n")
	fmt.Printf("   Execution Status: %s\n", txReceipt.ExecutionStatus)
	fmt.Printf("   Finality Status: %s\n", txReceipt.FinalityStatus)

	// Compute the deployed contract address
	deployedAddress := utils.PrecomputeAddressForUDC(classHashFelt, salt, constructorCalldata, utils.UDCCairoV0, accnt.Address)
	
	return deployedAddress.String(), txHash.String(), nil
}

// saveDeploymentInfo saves deployment information to LATEST_DEPLOYMENT.md
func saveDeploymentInfo(deployerAddress, txHash, classHash, deployedAddress string) error {
	content := fmt.Sprintf(`# Latest Permit2 Deployment Details

## Deployment Information

- **Deployer Contract Address**: %s
- **Deployment Transaction Hash**: %s
- **Class Hash**: %s
- **Deployed Contract Address**: %s
- **Deployment Time**: %s

## Notes

This contract was deployed using the Go deployment script. The Permit2 contract has no constructor arguments and was deployed using the Universal Deployer Contract (UDC).
`, deployerAddress, txHash, classHash, deployedAddress, time.Now().Format(time.RFC3339))

	// Write to LATEST_DEPLOYMENT.md in the go/ directory
	filename := "LATEST_DEPLOYMENT.md"
	if err := os.WriteFile(filename, []byte(content), 0644); err != nil {
		return fmt.Errorf("failed to write deployment file: %w", err)
	}

	return nil
}
