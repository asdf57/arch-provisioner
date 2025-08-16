package cmd

import "github.com/spf13/cobra"

var venvCmd = &cobra.Command{
	Use:   "venv",
	Short: "Spawn a development environment",
	Long: `Spawns a development environment either on metal or in a container.

Examples:
  hlcli venv -t metal -u http://vault -k token -i image -p http://prov`,
	RunE: func(cmd *cobra.Command, args []string) error {
		// actual logic here
		return nil
	},
}
