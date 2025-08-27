package deployment

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
)

// Deployer handles Permit2 contract deployment
type Deployer struct {
	account *account.Account
	client  *rpc.Provider
}

// NewDeployer creates a new deployment instance
func NewDeployer(rpcURL string, accountAddress, privateKey, publicKey string) (*Deployer, error) {
	// Initialize connection to RPC provider
	client, err := rpc.NewProvider(rpcURL)
	if err != nil {
		return nil, fmt.Errorf("error connecting to RPC provider: %s", err)
	}

	// Initialize the account memkeyStore
	ks := account.NewMemKeystore()
	privKeyBI, ok := new(big.Int).SetString(privateKey, 0)
	if !ok {
		return nil, fmt.Errorf("failed to convert private key to big.Int")
	}
	ks.Put(publicKey, privKeyBI)

	// Convert account address to felt
	accountAddressInFelt, err := utils.HexToFelt(accountAddress)
	if err != nil {
		return nil, fmt.Errorf("failed to transform account address: %s", err)
	}

	// Initialize the account (Cairo v2)
	accnt, err := account.NewAccount(client, accountAddressInFelt, publicKey, ks, account.CairoV2)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize account: %s", err)
	}

	return &Deployer{
		account: accnt,
		client:  client,
	}, nil
}

// DeployPermit2 deploys the Permit2 contract
func (d *Deployer) DeployPermit2(sierraPath, casmPath string) (*DeploymentResult, error) {
	// Step 1: Declare the contract
	fmt.Println("\n📋 Step 1: Declaring Permit2 contract...")
	classHash, err := d.declareContract(sierraPath, casmPath)
	if err != nil {
		return nil, fmt.Errorf("declaration failed: %s", err)
	}
	fmt.Printf("✅ Contract declaration completed! Class Hash: %s\n", classHash)

	// Step 2: Deploy the contract
	fmt.Println("\n📋 Step 2: Deploying Permit2 contract...")
	deployedAddress, txHash, err := d.deployContract(classHash)
	if err != nil {
		return nil, fmt.Errorf("deployment failed: %s", err)
	}

	fmt.Printf("✅ Contract deployed successfully!\n")
	fmt.Printf("   Deployed Address: %s\n", deployedAddress)
	fmt.Printf("   Transaction Hash: %s\n", txHash)

	return &DeploymentResult{
		ClassHash:       classHash,
		DeployedAddress: deployedAddress,
		TransactionHash: txHash,
		DeploymentTime:  time.Now(),
	}, nil
}

// declareContract declares the Permit2 contract
func (d *Deployer) declareContract(sierraPath, casmPath string) (string, error) {
	fmt.Printf("📋 Loading contract files:\n")
	fmt.Printf("   Sierra: %s\n", sierraPath)
	fmt.Printf("   Casm: %s\n", casmPath)

	// Check if contract files exist
	if _, err := os.Stat(sierraPath); os.IsNotExist(err) {
		return "", fmt.Errorf("sierra contract file not found: %s", sierraPath)
	}
	if _, err := os.Stat(casmPath); os.IsNotExist(err) {
		return "", fmt.Errorf("casm contract file not found: %s", casmPath)
	}

	// Unmarshalling the casm contract class from a JSON file
	casmClass, err := utils.UnmarshalJSONFileToType[contracts.CasmClass](casmPath, "")
	if err != nil {
		return "", fmt.Errorf("failed to parse casm contract: %s", err)
	}

	// Unmarshalling the sierra contract class from a JSON file
	contractClass, err := utils.UnmarshalJSONFileToType[contracts.ContractClass](sierraPath, "")
	if err != nil {
		return "", fmt.Errorf("failed to parse sierra contract: %s", err)
	}

	// Building and sending the declare transaction
	fmt.Println("📤 Declaring contract...")
	resp, err := d.account.BuildAndSendDeclareTxn(
		context.Background(),
		casmClass,
		contractClass,
		nil,
	)
	if err != nil {
		// Check if it's an "already declared" error
		if strings.Contains(err.Error(), "already declared") {
			fmt.Println("✅ Contract already declared, extracting class hash...")
			// Use the proper ClassHash function from the hash package
			classHash := hash.ClassHash(contractClass)
			return classHash.String(), nil
		}
		return "", err
	}

	// Wait for transaction receipt
	fmt.Println("⏳ Waiting for declaration confirmation...")
	_, err = d.account.WaitForTransactionReceipt(context.Background(), resp.Hash, time.Second)
	if err != nil {
		return "", fmt.Errorf("declare transaction failed: %s", err)
	}

	return resp.ClassHash.String(), nil
}

// deployContract deploys the Permit2 contract
func (d *Deployer) deployContract(classHash string) (string, string, error) {
	// Convert class hash to felt
	classHashFelt, err := utils.HexToFelt(classHash)
	if err != nil {
		return "", "", fmt.Errorf("invalid class hash: %s", err)
	}

	// Permit2 has no constructor arguments, so we pass empty calldata
	var constructorCalldata []*felt.Felt

	fmt.Println("📤 Sending deployment transaction...")

	// Deploy the contract with UDC
	resp, salt, err := d.account.DeployContractWithUDC(context.Background(), classHashFelt, constructorCalldata, nil, nil)
	if err != nil {
		return "", "", fmt.Errorf("failed to deploy contract: %s", err)
	}

	// Extract transaction hash from response
	txHash := resp.Hash
	fmt.Printf("⏳ Transaction sent! Hash: %s\n", txHash.String())
	fmt.Println("⏳ Waiting for transaction confirmation...")

	// Wait for transaction receipt
	txReceipt, err := d.account.WaitForTransactionReceipt(context.Background(), txHash, time.Second)
	if err != nil {
		return "", "", fmt.Errorf("failed to get transaction receipt: %s", err)
	}

	fmt.Printf("✅ Transaction confirmed!\n")
	fmt.Printf("   Execution Status: %s\n", txReceipt.ExecutionStatus)
	fmt.Printf("   Finality Status: %s\n", txReceipt.FinalityStatus)

	// Compute the deployed contract address
	deployedAddress := utils.PrecomputeAddressForUDC(classHashFelt, salt, constructorCalldata, utils.UDCCairoV0, d.account.Address)
	
	return deployedAddress.String(), txHash.String(), nil
}

// DeploymentResult contains the result of a deployment
type DeploymentResult struct {
	ClassHash       string    `json:"class_hash"`
	DeployedAddress string    `json:"deployed_address"`
	TransactionHash string    `json:"transaction_hash"`
	DeploymentTime  time.Time `json:"deployment_time"`
}
