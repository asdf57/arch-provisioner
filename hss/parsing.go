package main

type Config struct {
	All Hosts `yaml:"all"`
}

type Hosts struct {
	Hosts map[string]Host `yaml:"hosts"`
}

type Host struct {
	AnsibleHost string `yaml:"ansible_host"`
	AnsiblePort int    `yaml:"ansible_port"`
	PrimaryMAC  string `yaml:"primary_mac"`
	AnsibleUser string `yaml:"ansible_user"`
}

type HostVars struct {
	PrivateKeyPath string `yaml:"private_key_path"`
	PublicKeyPath  string `yaml:"public_key_path"`
}

type DistroConfig struct {
	PrivateSSHKey string `yaml:"private_ssh_key"`
	PublicSSHKey  string `yaml:"public_ssh_key"`
}

type LiveConfig struct {
	PrivateSSHKey string `yaml:"private_ssh_key"`
	PublicSSHKey  string `yaml:"public_ssh_key"`
}

type BuildIsoCommand struct {
	Distro       string `short:"d" description:"Linux distribution to build the ISO for" required:"true"`
	OutputDir    string `short:"o" description:"Output directory for the ISO (relative to the specified distro directory)" default:"out"`
	PublicSSHKey string `short:"s" description:"Public SSH key to use for provisioning" default:"provisioning_key.pub"`
}

type RunCommand struct {
	GIT_SSH_KEY string `short:"g" long:"git-key" description:"Environment variable containing the SSH key to use for Git" required:"false" default:"PROVISIONER_GIT_SSH_KEY"`
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
	Run      RunCommand      `command:"run" description:"Run the hss docker container"`
}
