import React, { createContext, useState } from 'react';

const ProvisionContext = createContext();

export function ProvisionContextProvider({ children }) {
  const [options, setOptions] = useState({
    ansible_port: 60022,
    iso_path: 'out/archlinux-2024.06.19-x86_64.iso',
    disk_size: '10G',
    disk_device: '/dev/vda',
    boot_partition_min: '1MiB',
    boot_partition_max: '512MiB',
    swap_partition_min: '512MiB',
    swap_partition_max: '2.5GiB',
    root_partition_min: '2.5GiB',
    root_partition_max: '100%',
    root_filesystem: 'ext4',
    root_password: '',
    locale: 'en_US.UTF-8',
    hostname: 'archhost',
    username: 'archuser',
    password: '',
    playbook: '../ansible/playbooks/main.yml',
    inventory: 'localhost,',
    ansible_host: 'localhost',
    ansible_user: 'root',
    ansible_ssh_private_key_file: '~/.ssh/arch_provisioning_key',
  });

  const handleChange = (e) => {
    setOptions((prevOptions) => ({
      ...prevOptions,
      [e.target.name]: e.target.value,
    }));
  };

  return (
    <ProvisionContext.Provider value={{ options, setOptions, handleChange }}>
      {children}
    </ProvisionContext.Provider>
  );
}

export { ProvisionContext };
