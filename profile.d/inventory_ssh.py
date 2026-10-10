"""Build container-local SSH configuration from resolved Ansible inventory."""

import ipaddress
import json
from pathlib import Path
import re
import shlex
import subprocess
from typing import TypeAlias, Union

JSONValue: TypeAlias = Union[None, bool, int, float, str, list["JSONValue"],
                             dict[str, "JSONValue"]]


def mapping(value: JSONValue) -> dict[str, JSONValue]:
    """Reject unexpected inventory structure before producing SSH directives."""
    if not isinstance(value, dict):
        raise ValueError("Expected an inventory mapping")
    return value


def text_field(host: dict[str, JSONValue], name: str, default: str) -> str:
    value = host.get(name, default)
    if not isinstance(value, str) or not value:
        raise ValueError(f"Invalid inventory field: {name}")
    return value


def safe_name(name: str) -> str:
    # SSH patterns and configuration control characters must never come from inventory.
    if not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9_.-]*", name):
        raise ValueError(f"Invalid inventory SSH name: {name!r}")
    return name


def render_config(inventory: JSONValue) -> str:
    """Render explicit host stanzas, preserving strict UID-qualified trust."""
    hosts = mapping(mapping(mapping(inventory).get("_meta")).get("hostvars"))
    lines = ["# Generated from resolved inventory at container startup."]
    for name, value in sorted(hosts.items()):
        host = mapping(value)
        address = text_field(host, "ansible_host", name)
        # HostName accepts DNS names as well as IPv4/IPv6; neither may inject directives.
        try:
            ipaddress.ip_address(address)
        except ValueError:
            safe_name(address)
        user = safe_name(text_field(host, "ansible_user", "ansible"))
        port = host.get("ansible_port", 22)
        if isinstance(port, bool) or not isinstance(port, (int, str)):
            raise ValueError("Invalid inventory SSH port")
        if not str(port).isdigit() or not 1 <= int(port) <= 65535:
            raise ValueError("Invalid inventory SSH port")
        options = shlex.split(text_field(host, "ansible_ssh_common_args", " "))
        alias = name
        # Managed Server inventory uses exactly this option. Refuse to silently
        # drop unfamiliar SSH options instead of changing connection semantics.
        if options:
            if len(options) != 2 or options[
                    0] != "-o" or not options[1].startswith("HostKeyAlias="):
                raise ValueError(f"Unsupported SSH common options for {name}")
            alias = options[1].split("=", 1)[1]
        lines.extend([
            "",
            f"Host {safe_name(name)}",
            f"    HostName {address}",
            f"    User {user}",
            f"    Port {port}",
            f"    HostKeyAlias {safe_name(alias)}",
            "    IdentityFile /home/keiichi/.ssh/id_ansible_mgmt",
            "    CertificateFile /home/keiichi/.ssh/id_ansible_mgmt-cert.pub",
            "    IdentitiesOnly yes",
            "    IdentityAgent none",
            "    ForwardAgent no",
            "    UpdateHostKeys no",
            "    HostKeyAlgorithms ssh-ed25519",
            "    GlobalKnownHostsFile /dev/null",
            "    StrictHostKeyChecking yes",
            "    UserKnownHostsFile /home/keiichi/.ssh/known_hosts",
        ])
    return "\n".join(lines) + "\n"


def main() -> None:
    """Resolve inherited host variables and install configuration without secrets."""
    result = subprocess.run(["ansible-inventory", "--list"],
                            check=True,
                            capture_output=True,
                            text=True)
    inventory: JSONValue = json.loads(result.stdout)
    content = render_config(inventory)
    config = Path("/home/keiichi/.ssh/config")
    config.write_text(content)
    config.chmod(0o600)


if __name__ == "__main__":
    main()
