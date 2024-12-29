package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/relex/aini"
)

func (b *BuildCommand) Execute(args []string) error {
	ini, err := aini.ParseFile("../ansible/inventory/inventory.ini")
	if err != nil {
		log.Fatalf("Failed to parse inventory file: %v", err)
	}

	if !isDirExists("ssh_keys") {
		err := os.Mkdir("ssh_keys", 0755)
		if err != nil {
			log.Fatalf("Failed to create SSH keys directory: %v", err)
		}
	}

	// Copy git provisioning key
	copyFile(filepath.Join(os.Getenv("HOME"), ".ssh", "git_provisioning_key"), "ssh_keys/git_provisioning_key")

	for hostName := range ini.Hosts {
		if hostName == "localhost" {
			continue
		}

		fmt.Printf("[*] Copying SSH keys for %s\n", hostName)

		var pubkey_name = "id_" + hostName + ".pub"
		var privkey_name = "id_" + hostName

		copyFile(filepath.Join(os.Getenv("HOME"), ".ssh", pubkey_name), "ssh_keys/"+pubkey_name)
		copyFile(filepath.Join(os.Getenv("HOME"), ".ssh", privkey_name), "ssh_keys/"+privkey_name)
	}

	//Build the HSS Docker container
	runCommand("docker build --platform linux/amd64 -t hss .", "..")

	os.RemoveAll("ssh_keys")

	return nil
}
