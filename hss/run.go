package main

import (
	"fmt"
	"os"
)

func (b *RunCommand) Execute(args []string) error {

	gitSshKey := os.Getenv(b.GIT_SSH_KEY)

	runCommand(fmt.Sprintf("docker run --rm -it -e GIT_SSH_KEY=%s hss:latest", gitSshKey), ".")

	return nil
}
