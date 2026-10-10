"""Configuration rendering tests; no network or managed-node operations."""

import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location(
    "inventory_ssh",
    Path(__file__).parents[1] / "profile.d/inventory_ssh.py")
assert spec is not None and spec.loader is not None
inventory_ssh = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inventory_ssh)


class InventorySSHTests(unittest.TestCase):

    def render(self, **variables):
        return inventory_ssh.render_config({
            "_meta": {
                "hostvars": {
                    "beelink": {
                        "ansible_host": "10.1.1.243",
                        **variables
                    }
                }
            }
        })

    def test_managed_identity_and_connection(self):
        config = self.render(
            ansible_ssh_common_args="-o HostKeyAlias=server-uid",
            ansible_port=2222)
        for expected in ("Host beelink", "HostName 10.1.1.243", "User ansible",
                         "Port 2222", "HostKeyAlias server-uid",
                         "StrictHostKeyChecking yes", "CertificateFile "):
            self.assertIn(expected, config)

    def test_explicit_inventory_trust_uses_host_name(self):
        self.assertIn("HostKeyAlias beelink", self.render())

    def test_ipv6(self):
        self.assertIn("HostName 2001:db8::1",
                      self.render(ansible_host="2001:db8::1"))

    def test_refuse_injection_and_unsupported_options(self):
        for variables in ({
                "ansible_host": "host\nProxyCommand evil"
        }, {
                "ansible_user": "*"
        }, {
                "ansible_port": True
        }, {
                "ansible_port": 65536
        }, {
                "ansible_ssh_common_args":
                "-o StrictHostKeyChecking=no"
        }, {
                "ansible_ssh_common_args": "-o HostKeyAlias=*"
        }):
            with self.subTest(
                    variables=variables), self.assertRaises(ValueError):
                self.render(**variables)


if __name__ == "__main__":
    unittest.main()
