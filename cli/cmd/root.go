package cmd

import "github.com/spf13/cobra"

var rootCmd = &cobra.Command{
	Use:   "hlcli",
	Short: "Homelab CLI",
	Long:  "hlcli is a CLI tool for managing homelabs.",
}
