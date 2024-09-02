package main

type Host struct {
	AnsibleHost string `yaml:"ansible_host"`
}

type Hosts map[string]Host

type Servers struct {
	Hosts Hosts `yaml:"hosts"`
}

type HostsConfig struct {
	Servers Servers `yaml:"servers"`
}

type HostVars struct {
	PrivateKeyPath string `yaml:"private_key_path"`
	PublicKeyPath  string `yaml:"public_key_path"`
}

type DistroConfig struct {
	PrivateSSHKey string `yaml:"private_ssh_key"`
	PublicSSHKey  string `yaml:"public_ssh_key"`
}

type LiveConfig map[string]DistroConfig

type BuildIsoCommand struct {
	Distro       string `short:"d" description:"Linux distribution to build the ISO for" required:"true"`
	OutputDir    string `short:"o" description:"Output directory for the ISO (relative to the specified distro directory)" default:"out"`
	PublicSSHKey string `short:"s" description:"Public SSH key to use for provisioning" default:"provisioning_key.pub"`
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
