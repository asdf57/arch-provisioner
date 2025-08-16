package main

import (
	"os"

	"github.com/spf13/cobra"
)

/*
 * hlcli venv -t [metal|container] -u <vault-url> -k <vault-token> -i <image> -p <provisioner-url>
	- Spawns a dev environment (container or metal) with the given image
	- Actions:
		- Sets HLCI_IN_VENV to true (used to optionally prevent invocation of subsequent commands outside of the venv)
	- Requires:
		- Vault URL
		- Vault Token
		- Image name
		- Provisioner URL
 * hlcli upload <file> -p <provisioner-url>
	- Uploads a file to the provisioner
	- Requires:
		- provisioner URL (HLCLI_PROVISIONER_URL)
		- file to upload
 * hlcli init <infra|servers>
	- infra: Initializes the infrastructure (docker-compose cluster). Must be
	- servers: Runs the provisioning playbook
	- Actions:
		- If infra is specified and not in venv, invoke metal venv with the init command (e.g. something like: bash -c "cmd here")
		- If servers is specified and not in venv, invoke metal venv with the init command (e.g. something like: bash -c "cmd here")
	- Requires:
		- init:
			- Must be run from METAL venv
			- provisioner URL (HLCLI_PROVISIONER_URL)
			- vault URL (HLCLI_VAULT_URL)
		- servers:
			- Can be run from either METAL or CONTAINER venv
 * hlcli ls
	- Queries the provisioner for a list of the current servers
	- Returns a list of servers with their IDs, names, and statuses
 * hlcli rm <server-id>
	- Removes a server with the given ID from the provisioner (API call)
*/

var rootCmd = &cobra.Command{
	Use:   "hlcli",
	Short: "Homelab CLI",
	Long:  "hlcli is a CLI tool for managing homelabs.",
}

// func spawnContainer(cmd *cobra.Command, args []string) {
// 	fmt.Printf("Running container with image: %s\n", opts.Image)
// 	cmdStr := fmt.Sprintf("docker run --rm -it --name provisioner -e VAULT_ADDR=%s -e VAULT_TOKEN=%s %s", opts.VaultUrl, opts.VaultToken, opts.Image)
// 	cmd := exec.Command("sh", "-c", cmdStr)
// 	cmd.Stdout = os.Stdout
// 	cmd.Stderr = os.Stderr
// 	cmd.Stdin = os.Stdin
// 	if err := cmd.Run(); err != nil {
// 		fmt.Fprintf(os.Stderr, "Error running container: %v\n", err)
// 		os.Exit(1)
// 	}
// }

// func loadTasks(cmd *cobra.Command, args []string) {

// }

func main() {
	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}
