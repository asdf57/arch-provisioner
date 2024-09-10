package main

import (
	"log"
	"os"
	"os/exec"

	"gopkg.in/yaml.v3"
)

var VALID_DISTROS []string = []string{"arch", "debian", "ubuntu"}

func parseYamlFile(filePath string, config interface{}) {
	yamlFile, err := os.ReadFile(filePath)
	if err != nil {
		log.Fatalf("Failed to read YAML file: %v", err)
	}

	err = yaml.Unmarshal(yamlFile, config)
	if err != nil {
		log.Fatalf("Failed to parse YAML: %v", err)
	}
}

func runCommand(command string, dir string) {
	cmd := exec.Command("/bin/sh", "-c", command)

	if dir != "" {
		cmd.Dir = dir
	}

	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	err := cmd.Run()
	if err != nil {
		log.Fatalf("Failed to run command: %v", err)
	}
}

func isValidDistro(distro string) bool {
	for _, validDistro := range VALID_DISTROS {
		if distro == validDistro {
			return true
		}
	}
	return false
}

func copyFile(src string, dest string) {
	originalFile, err := os.Open(src)
	if err != nil {
		log.Fatalf("Failed to open file: %v", err)
	}
	defer originalFile.Close()

	newFile, err := os.Create(dest)
	if err != nil {
		log.Fatalf("Failed to create file: %v", err)
	}
	defer newFile.Close()

	_, err = originalFile.WriteTo(newFile)
	if err != nil {
		log.Fatalf("Failed to copy file: %v", err)
	}
}

func isFileExists(filePath string) bool {
	info, err := os.Stat(filePath)
	if os.IsNotExist(err) {
		return false
	}

	return !info.IsDir()
}

func isDirExists(filePath string) bool {
	info, err := os.Stat(filePath)
	if os.IsNotExist(err) {
		return false
	}

	return info.IsDir()
}
