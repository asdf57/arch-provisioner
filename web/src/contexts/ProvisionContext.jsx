import React, { createContext, useEffect, useState } from 'react';
import { set } from 'lodash';

const ProvisionContext = createContext();

export function ProvisionContextProvider({ children }) {
  const [options, setOptions] = useState({
    ansible: {
      host: 'localhost',
      port: 60022,
      user: 'root',
      inventory: ['localhost'],
      private_key: '~/.ssh/arch_provisioning_key',
      playbook: '../ansible/playbooks/main.yml',
    },
    disk: {
      device: '/dev/vda',
      size: '10GiB',
      partitions: [
        {
          min: '1MiB',
          max: '512MiB',
          fs: 'ext4',
          flags: ['boot', 'esp'],
        },
        {
          min: '512MiB',
          max: '2.5GiB',
          fs: 'swap',
        },
        {
          min: '2.5GiB',
          max: '100%',
          fs: 'ext4',
        },
      ],
    },
    root_password: '',
    hostname: 'archhost',
    locale: 'en_US.UTF-8',
    users: [
      {
        username: 'archuser',
        password: '',
        groups: ['wheel', 'users'],
        shell: '/bin/bash',
      },
    ],
    packages: [
      "git",
    ],
  });

  /**
   * Takes in a key-value pair and updates the options state with the new value.
   */
  const handleChange = (e) => {
    const { name, value } = e.target;
    setOptions((prevOptions) => {
      const newOptions = { ...prevOptions };
      set(newOptions, name, value);
      return newOptions;
    });
  };

  return (
    <ProvisionContext.Provider value={{ options, setOptions, handleChange }}>
      {children}
    </ProvisionContext.Provider>
  );
}

export { ProvisionContext };
