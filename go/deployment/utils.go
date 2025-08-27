package deployment

import (
	"fmt"
	"os"
	"time"
)

// SaveDeploymentInfo saves deployment information to LATEST_DEPLOYMENT.md
func SaveDeploymentInfo(deployerAddress string, result *DeploymentResult) error {
	content := fmt.Sprintf(`# Latest Permit2 Deployment Details

## Deployment Information

- **Deployer Contract Address**: %s
- **Deployment Transaction Hash**: %s
- **Class Hash**: %s
- **Deployed Contract Address**: %s
- **Deployment Time**: %s

## Notes

This contract was deployed using the Go deployment script. The Permit2 contract has no constructor arguments and was deployed using the Universal Deployer Contract (UDC).
`, deployerAddress, result.TransactionHash, result.ClassHash, result.DeployedAddress, result.DeploymentTime.Format(time.RFC3339))

	// Write to LATEST_DEPLOYMENT.md in the current directory
	filename := "LATEST_DEPLOYMENT.md"
	if err := os.WriteFile(filename, []byte(content), 0644); err != nil {
		return fmt.Errorf("failed to write deployment file: %w", err)
	}

	return nil
}
