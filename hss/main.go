package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/jessevdk/go-flags"
	"gopkg.in/yaml.v3"
)

var VALID_DISTROS []string = []string{"arch", "debian", "fedora", "ubuntu"}

type Host struct {
	AnsibleHost string `yaml:"ansible_host"`
}

type Hosts map[string]Host

type Servers struct {
	Hosts Hosts `yaml:"hosts"`
}

type Config struct {
	Servers Servers `yaml:"servers"`
}

type HostVars struct {
	PrivateKeyPath string `yaml:"private_key_path"`
}

type DistroConfig struct {
	PrivateSSHKey string `yaml:"private_ssh_key"`
	PublicSSHKey  string `yaml:"public_ssh_key"`
}

type LiveConfig struct {
	Distros map[string]DistroConfig `yaml:"distros"`
}

type BuildIsoCommand struct {
	Distro     string `short:"d" description:"Linux distribution to build the ISO for" required:"true"`
	OutputDir  string `short:"o" description:"Output directory for the ISO (relative to the specified distro directory)" default:"output"`
	PrivateKey string `short:"s" description:"The name of the SSH key to use for accessing a server (must already exist)" required:"true"`
}

type BuildCommand struct {
}

type StartCommand struct {
}

type Options struct {
	Verbose  []bool          `short:"v" long:"verbose" description:"Show verbose debug information"`
	Start    StartCommand    `command:"start" description:"Start the hss docker container"`
	BuildIso BuildIsoCommand `command:"buildiso" description:"Build an ISO"`
	Build    BuildCommand    `command:"build" description:"Build the hss docker container"`
}

// Execute method will be called when the buildiso command is used
func (b *BuildIsoCommand) Execute(args []string) error {
	fmt.Println("Executing buildiso command")

	if !isValidDistro(b.Distro) {
		log.Panicf("Invalid distro: %s", b.Distro)
	}

	return nil
}

func isFileExists(filePath string) bool {
	info, err := os.Stat(filePath)
	if os.IsNotExist(err) {
		return false
	}

	return !info.IsDir()
}

func isSSHKeyExists(privateKey string) bool {
	privateKeyPath := filepath.Join(os.Getenv("HOME"), ".ssh", privateKey+".pub")
	return isFileExists(privateKeyPath)
}

func isValidDistro(distro string) bool {
	for _, validDistro := range VALID_DISTROS {
		if distro == validDistro {
			return true
		}
	}
	return false
}

func main() {
	var opts Options

	_, err := flags.Parse(&opts)
	if err != nil {
		os.Exit(1)
	}

	filePath, _ := filepath.Abs("../ansible/inventory/hosts.yml")

	// Read the YAML file
	yamlFile, err := os.ReadFile(filePath)
	if err != nil {
		log.Fatalf("Failed to read YAML file: %v", err)
	}

	// Parse the YAML into the Inventory struct
	var config Config
	err = yaml.Unmarshal(yamlFile, &config)
	if err != nil {
		log.Fatalf("Failed to parse YAML: %v", err)
	}

	for hostName, _ := range config.Servers.Hosts {
		hostVarsFilePath, _ := filepath.Abs(fmt.Sprintf("../ansible/host_vars/%s.yml", hostName))
		hostVarsYamlFile, err := os.ReadFile(hostVarsFilePath)
		if err != nil {
			log.Fatalf("Failed to read host_vars YAML file: %v", err)
		}

		var hostVars HostVars
		err = yaml.Unmarshal(hostVarsYamlFile, &hostVars)
		if err != nil {
			log.Fatalf("Failed to parse host_vars YAML: %v", err)
		}

		fmt.Printf("Host: %s\n", hostVars.PrivateKeyPath)

		//Now, temporarily copy each private key to this directory and set the environment variable so the docker container knows what to copy

	}
}
