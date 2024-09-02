package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
)

func (b *BuildIsoCommand) Execute(args []string) error {
	if !isValidDistro(b.Distro) {
		log.Fatalf("Invalid distro: %s", b.Distro)
	}

	if b.PublicSSHKey == "" {
		log.Fatalf("Public SSH key cannot be empty")
	}

	if b.OutputDir == "" {
		log.Fatalf("Output directory cannot be empty")
	}

	outputDir := filepath.Join("../iso", b.Distro, b.OutputDir)

	if !isDirExists(outputDir) {
		fmt.Println("Creating output directory")
		err := os.MkdirAll(outputDir, 0755)
		if err != nil {
			log.Fatalf("Failed to create output directory: %v", err)
		}
	}

	filePath, _ := filepath.Abs("../liveconfig.yml")

	var config LiveConfig
	parseYamlFile(filePath, &config)

	sshFileName := config[b.Distro].PublicSSHKey
	if b.PublicSSHKey != "provisioning_key.pub" {
		sshFileName = b.PublicSSHKey
	}

	sshPublicKeyPath := filepath.Join(os.Getenv("HOME"), ".ssh", sshFileName)

	if !isFileExists(sshPublicKeyPath) {
		log.Fatalf("SSH public key does not exist: %s", sshPublicKeyPath)
	}

	log.Printf("[*] Using SSH public key: %s", sshPublicKeyPath)

	copyFile(sshPublicKeyPath, "../iso/"+b.Distro+"/"+b.Distro+"_provisioning_key.pub")

	runCommand("docker build --platform linux/amd64 -t arch-iso-builder .", "../iso/"+b.Distro)

	absOutputDir, _ := filepath.Abs(outputDir)

	runCommand(fmt.Sprintf("docker run --platform linux/amd64 --privileged --rm -v %s:/output arch-iso-builder", absOutputDir), "../iso/"+b.Distro)

	os.Remove("../iso/" + b.Distro + "/" + b.Distro + "_provisioning_key.pub")

	return nil
}
