package main

import (
	"os"

	"github.com/jessevdk/go-flags"
)

func main() {
	var opts Options

	_, err := flags.Parse(&opts)
	if err != nil {
		os.Exit(1)
	}
}
