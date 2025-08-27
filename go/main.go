package main

import (
	"fmt"
	"os"

	"github.com/NethermindEth/oif-starknet/go/deployment"
	"github.com/joho/godotenv"
)

const (
	// Contract file paths relative to the go/ directory
	sierraContractFilePath = "../target/dev/permit2_Permit2.contract_class.json"
	casmContractFilePath   = "../target/dev/permit2_Permit2.compiled_contract_class.json"
	
	// Network configuration
	networkName = "Starknet"
)

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

	// Create deployer instance
	deployer, err := deployment.NewDeployer(rpcURL, accountAddress, accountPrivateKey, accountPublicKey)
	if err != nil {
		panic(fmt.Sprintf("❌ Failed to create deployer: %s", err))
	}

	fmt.Println("✅ Connected to Starknet RPC")

	// Deploy the contract
	result, err := deployer.DeployPermit2(sierraContractFilePath, casmContractFilePath)
	if err != nil {
		panic(fmt.Sprintf("❌ Deployment failed: %s", err))
	}

	fmt.Printf("✅ Contract deployed successfully!\n")
	fmt.Printf("   Deployed Address: %s\n", result.DeployedAddress)
	fmt.Printf("   Transaction Hash: %s\n", result.TransactionHash)

	// Save deployment information
	fmt.Println("\n📋 Saving deployment information...")
	if err := deployment.SaveDeploymentInfo(accountAddress, result); err != nil {
		fmt.Printf("⚠️  Failed to save deployment info: %s\n", err)
	} else {
		fmt.Println("✅ Deployment information saved to LATEST_DEPLOYMENT.md")
	}

	fmt.Println("\n🎉 Permit2 deployment completed successfully!")
}
