package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
)

func (b *BuildCommand) Execute(args []string) error {
	var config HostsConfig
	parseYamlFile("../ansible/inventory/inventory.yml", &config)

	//Check if temporary SSH directory needed for HSS build exists
	if !isDirExists("ssh_keys") {
		err := os.Mkdir("ssh_keys", 0755)
		if err != nil {
			log.Fatalf("Failed to create SSH keys directory: %v", err)
		}
	}

	//Grab the public and private keys from the host_vars directory for each host
	for hostName := range config.Servers.Hosts {
		var hostVars HostVars
		hostVarsFilePath, _ := filepath.Abs(fmt.Sprintf("../ansible/host_vars/%s.yml", hostName))
		parseYamlFile(hostVarsFilePath, &hostVars)

		copyFile(filepath.Join(os.Getenv("HOME"), ".ssh", hostVars.PublicKeyPath), "ssh_keys/"+hostName+"_public_key.pub")
		copyFile(filepath.Join(os.Getenv("HOME"), ".ssh", hostVars.PrivateKeyPath), "ssh_keys/"+hostName+"_private_key")
	}

	var liveConfig LiveConfig
	parseYamlFile("../liveconfig.yml", &liveConfig)

	//Copy the private provisioning key the ssh_keys directory
	copyFile(filepath.Join(os.Getenv("HOME"), ".ssh", liveConfig.PrivateSSHKey), "ssh_keys/"+"provisioning_key")

	//Build the HSS Docker container
	runCommand("docker build -t hss .", "..")

	os.RemoveAll("ssh_keys")

	return nil
}
