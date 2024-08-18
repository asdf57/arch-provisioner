from unittest.mock import patch
from pydantic import ValidationError
import pytest
from server.schema import Ansible, EFIPartition, RootPartition, SwapPartition, User, validate_size, Partition, Disk

TEST_SCHEMA_1 = {
    "ansible": {
        "host": "192.168.1.1",
        "port": 22,
        "user": "admin",
        "inventory": ["192.168.1.49"],
        "private_key": "/path/to/private/key",
        "playbook": "/path/to/playbook.yml"
    },
    "disk": {
        "device": "/dev/sda",
        "size": "500GiB",
        "partitions": [
            {
                "min": "100GiB",
                "max": "200GiB"
            },
            {
                "min": "200GiB",
                "max": "300GiB"
            },
            {
                "min": "300GiB",
                "max": "400GiB"
            }
        ]
    },
    "root_password": "password",
    "hostname": "my-server",
    "locale": "en_US.UTF-8",
    "users": [
        {
            "username": "user1",
            "password": "password1",
            "groups": ["sudo", "users"],
            "shell": "/bin/bash"
        },
        {
            "username": "user2",
            "password": "password2",
            "groups": ["users"],
            "shell": "/bin/bash"
        }
    ],
    "packages": ["vim", "git", "python3"]
}

def test_validate_size_with_valid_and_invalid_inputs():
    assert validate_size('50%') == '50%'
    assert validate_size('100MiB') == '100MiB'
    assert validate_size('1GiB') == '1GiB'
    with pytest.raises(ValueError):
        validate_size('50')
    with pytest.raises(ValueError):
        validate_size('100MB')
    with pytest.raises(ValueError):
        validate_size('1GB')
    with pytest.raises(ValueError):
        validate_size('101%')
    with pytest.raises(ValueError):
        validate_size('abc')

def test_missing_required_fields_in_efi_partition_raises_validation_error():
    with pytest.raises(ValueError) as e:
        disk = Disk(
            device="/dev/sda",
            size="500GiB",
            partitions=[
                EFIPartition(),
                SwapPartition(start="2049MiB", end="400GiB", number="2", unit="GiB"),
                RootPartition(start="2049MiB", end="400GiB", number="3", unit="GiB", fs="ext4"),
            ]
        )

    assert "4 validation errors for EFIPartition" in str(e.value)
    assert "number\n  Field required" in str(e.value)
    assert "start\n  Field required" in str(e.value)
    assert "end\n  Field required" in str(e.value)
    assert "unit\n  Field required" in str(e.value)

def test_missing_required_fields_in_swap_partition_raises_validation_error():
    with pytest.raises(ValueError) as e:
        disk = Disk(
            device="/dev/sda",
            size="500GiB",
            partitions=[
                EFIPartition(start="2049MiB", end="400GiB", number="1", unit="GiB"),
                SwapPartition(),
                RootPartition(start="2049MiB", end="400GiB", number="3", unit="GiB", fs="ext4"),
            ]
        )

    assert "4 validation errors for SwapPartition" in str(e.value)
    assert "number\n  Field required" in str(e.value)
    assert "start\n  Field required" in str(e.value)
    assert "end\n  Field required" in str(e.value)
    assert "unit\n  Field required" in str(e.value)

def test_missing_required_fields_in_root_partition_raises_validation_error():
    with pytest.raises(ValueError) as e:
        disk = Disk(
            device="/dev/sda",
            size="500GiB",
            partitions=[
                EFIPartition(start="2049MiB", end="400GiB", number="1", unit="GiB"),
                SwapPartition(start="2049MiB", end="400GiB", number="2", unit="GiB"),
                RootPartition(),
            ]
        )

    assert "5 validation errors for RootPartition" in str(e.value)
    assert "number\n  Field required" in str(e.value)
    assert "start\n  Field required" in str(e.value)
    assert "end\n  Field required" in str(e.value)
    assert "unit\n  Field required" in str(e.value)
    assert "fs\n  Field required" in str(e.value)

def test_too_few_flags_in_efi_partition_raises_validation_error():
    with pytest.raises(ValueError) as e:
        disk = Disk(
            device="/dev/sda",
            size="500GiB",
            partitions=[
                EFIPartition(start="1MiB", end="512MiB", number="1", unit="MiB", flags=["boot"]),  # Missing 'esp'
                SwapPartition(start="513MiB", end="1024MiB", number="2", unit="MiB"),
                RootPartition(start="1025MiB", end="500GiB", number="3", unit="GiB", fs="ext4"),
            ]
        )

    assert "Flags must include both 'boot' and 'esp'" in str(e.value)

def test_additional_flags_in_efi_partition_is_successful():
    disk = Disk(
        device="/dev/sda",
        size="500GiB",
        partitions=[
            EFIPartition(start="1MiB", end="512MiB", number="1", unit="MiB", flags=["boot", "esp", "LVM"]),
            SwapPartition(start="513MiB", end="1024MiB", number="2", unit="MiB"),
            RootPartition(start="1025MiB", end="500GiB", number="3", unit="GiB", fs="ext4"),
        ]
    )

    assert disk.partitions[0].flags == ["boot", "esp", "LVM"]

def test_no_flags_in_efi_partition_raises_validation_error():
    with pytest.raises(ValueError) as e:
        disk = Disk(
            device="/dev/sda",
            size="500GiB",
            partitions=[
                EFIPartition(start="1MiB", end="512MiB", number="1", unit="MiB", flags=[]),  # Missing 'boot' and 'esp'
                SwapPartition(start="513MiB", end="1024MiB", number="2", unit="MiB"),
                RootPartition(start="1025MiB", end="500GiB", number="3", unit="GiB", fs="ext4"),
            ]
        )

    assert "Flags must include both 'boot' and 'esp'" in str(e.value)

def test_not_specifying_flags_in_efi_partition_defaults_to_boot_and_esp():
    disk = Disk(
        device="/dev/sda",
        size="500GiB",
        partitions=[
            EFIPartition(start="1MiB", end="512MiB", number="1", unit="MiB"),
            SwapPartition(start="513MiB", end="1024MiB", number="2", unit="MiB"),
            RootPartition(start="1025MiB", end="500GiB", number="3", unit="GiB", fs="ext4"),
        ]
    )

    assert disk.partitions[0].flags == ["boot", "esp"]

def test_one_invalid_flag_in_efi_partition_raises_validation_error():
    with pytest.raises(ValueError) as e:
        disk = Disk(
            device="/dev/sda",
            size="500GiB",
            partitions=[
                EFIPartition(start="1MiB", end="512MiB", number="1", unit="MiB", flags=["boot", "hidden"]), # Invalid flag replacing 'esp'
                SwapPartition(start="513MiB", end="1024MiB", number="2", unit="MiB"),
                RootPartition(start="1025MiB", end="500GiB", number="3", unit="GiB", fs="ext4"),
            ]
        )

    assert "Flags must include both 'boot' and 'esp'" in str(e.value)

def test_too_few_flags_in_swap_partition_raises_validation_error():
    with pytest.raises(ValueError) as e:
        disk = Disk(
            device="/dev/sda",
            size="500GiB",
            partitions=[
                EFIPartition(start="1MiB", end="512MiB", number="1", unit="MiB"),
                SwapPartition(start="513MiB", end="1024MiB", number="2", unit="MiB", flags=["boot"]),  # Invalid flag
                RootPartition(start="1025MiB", end="500GiB", number="3", unit="GiB", fs="ext4"),
            ]
        )

    assert "Flags must include 'swap'" in str(e.value)

def test_additional_flags_in_swap_partition_is_successful():
    disk = Disk(
        device="/dev/sda",
        size="500GiB",
        partitions=[
            EFIPartition(start="1MiB", end="512MiB", number="1", unit="MiB"),
            SwapPartition(start="513MiB", end="1024MiB", number="2", unit="MiB", flags=["swap", "PREP"]),
            RootPartition(start="1025MiB", end="500GiB", number="3", unit="GiB", fs="ext4"),
        ]
    )

    assert disk.partitions[1].flags == ["swap", "PREP"]

def test_no_flags_in_swap_partition_raises_validation_error():
    with pytest.raises(ValueError) as e:
        disk = Disk(
            device="/dev/sda",
            size="500GiB",
            partitions=[
                EFIPartition(start="1MiB", end="512MiB", number="1", unit="MiB"),
                SwapPartition(start="513MiB", end="1024MiB", number="2", unit="MiB", flags=[]),  # Missing 'swap'
                RootPartition(start="1025MiB", end="500GiB", number="3", unit="GiB", fs="ext4"),
            ]
        )

    assert "Flags must include 'swap'" in str(e.value)

def test_not_specifying_flags_in_swap_partition_defaults_to_swap():
    disk = Disk(
        device="/dev/sda",
        size="500GiB",
        partitions=[
            EFIPartition(start="1MiB", end="512MiB", number="1", unit="MiB"),
            SwapPartition(start="513MiB", end="1024MiB", number="2", unit="MiB"),
            RootPartition(start="1025MiB", end="500GiB", number="3", unit="GiB", fs="ext4"),
        ]
    )

    assert disk.partitions[1].flags == ["swap"]

def test_one_invalid_flag_in_swap_partition_raises_validation_error():
    with pytest.raises(ValueError) as e:
        disk = Disk(
            device="/dev/sda",
            size="500GiB",
            partitions=[
                EFIPartition(start="1MiB", end="512MiB", number="1", unit="MiB"),
                SwapPartition(start="513MiB", end="1024MiB", number="2", unit="MiB", flags=["bios_grub"]),  # Invalid flag replacing 'swap'
                RootPartition(start="1025MiB", end="500GiB", number="3", unit="GiB", fs="ext4"),
            ]
        )

    assert "Flags must include 'swap'" in str(e.value)

def test_adding_flags_to_root_partition_is_successful():
    disk = Disk(
        device="/dev/sda",
        size="500GiB",
        partitions=[
            EFIPartition(start="1MiB", end="512MiB", number="1", unit="MiB"),
            SwapPartition(start="513MiB", end="1024MiB", number="2", unit="MiB"),
            RootPartition(start="1025MiB", end="500GiB", number="3", unit="GiB", fs="ext4", flags=["DIAG", "LVM"]),
        ]
    )

    assert disk.partitions[2].flags == ["DIAG", "LVM"]

def test_changing_required_value_in_swap_partition_raises_validation_error():
    with pytest.raises(ValueError) as e:
        disk = Disk(
            device="/dev/sda",
            size="500GiB",
            partitions=[
                EFIPartition(start="1MiB", end="512MiB", number="1", unit="MiB"),
                SwapPartition(start="513MiB", end="1024MiB", number="2", unit="MiB", fs="invalid"),
                RootPartition(start="1025MiB", end="500GiB", number="3", unit="GiB", fs="ext4", flags=["a", "b"]),
            ]
        )

    # File system must be linux-swap for swap partition, not 'invalid'
    assert "fs\n  Input should be 'linux-swap'" in str(e.value)

def test_excluding_root_partition_raises_validation_error():
    with pytest.raises(ValueError) as e:
        disk = Disk(
            device="/dev/sda",
            size="500GiB",
            partitions=[
                EFIPartition(start="1MiB", end="512MiB", number="1", unit="MiB"),
                SwapPartition(start="513MiB", end="1024MiB", number="2", unit="MiB"),
            ]
        )

    assert "1 validation error for Disk" in str(e.value)
    assert "There must be at least one root partition" in str(e.value)

def test_excluding_efi_partition_raises_validation_error():
    with pytest.raises(ValueError) as e:
        disk = Disk(
            device="/dev/sda",
            size="500GiB",
            partitions=[
                SwapPartition(start="1MiB", end="512MiB", number="1", unit="MiB"),
                RootPartition(start="513MiB", end="1024MiB", number="2", unit="MiB", fs="ext4"),
            ]
        )

    assert "1 validation error for Disk" in str(e.value)
    assert "There must be exactly one EFI partition" in str(e.value)

def test_excluding_swap_partition_is_successful():
    disk = Disk(
        device="/dev/sda",
        size="500GiB",
        partitions=[
            EFIPartition(start="1MiB", end="512MiB", number="1", unit="MiB"),
            RootPartition(start="513MiB", end="500GiB", number="2", unit="GiB", fs="ext4"),
        ]
    )

    assert len(disk.partitions) == 2

def test_multiple_efi_partitions_raises_validation_error():
    with pytest.raises(ValueError) as e:
        disk = Disk(
            device="/dev/sda",
            size="500GiB",
            partitions=[
                EFIPartition(start="1MiB", end="512MiB", number="1", unit="MiB"),
                SwapPartition(start="1025MiB", end="1536MiB", number="3", unit="MiB"),
                EFIPartition(start="513MiB", end="1024MiB", number="2", unit="MiB"),
                RootPartition(start="1537MiB", end="500GiB", number="4", unit="GiB", fs="ext4"),
            ]
        )

    assert "There must be exactly one EFI partition" in str(e.value)

def test_invalid_partition_type_for_general_partition_raises_validation_error():
    with pytest.raises(ValueError) as e:
        disk = Disk(
        device="/dev/sda",
        size="500GiB",
        partitions=[
            Partition(type="invalid", align="optimal", fs="ext4", label="root", flags=[], name="Root Partition", resize="false", state="present", start="1025MiB", end="500GiB", number="4", unit="GiB"),
            Partition(type="efi", align="optimal", fs="fat32", label="gpt", flags=['boot', 'esp'], name="EFI System", resize="false", state="present", start="1MiB", end="512MiB", number="1", unit="MiB"),
            Partition(type="swap", align="optimal", fs="linux-swap", label="swap", flags=['swap'], name="Swap", resize="false", state="present", start="513MiB", end="1024MiB", number="2", unit="MiB"),
            Partition(type="general", align="optimal", fs="ext4", label="root", flags=[], name="Root Partition", resize="false", state="present", start="1025MiB", end="500GiB", number="3", unit="GiB"),
        ]
    )

    assert "Invalid partition type" in str(e.value)

def test_creating_swap_efi_and_root_paritions_using_ordinary_partitions_succeeds():
    disk = Disk(
        device="/dev/sda",
        size="500GiB",
        partitions=[
            Partition(type="efi", align="optimal", fs="fat32", label="gpt", flags=['boot', 'esp'], name="EFI System", resize="false", state="present", start="1MiB", end="512MiB", number="1", unit="MiB"),
            Partition(type="swap", align="optimal", fs="linux-swap", label="swap", flags=['swap'], name="Swap", resize="false", state="present", start="513MiB", end="1024MiB", number="2", unit="MiB"),
            Partition(type="general", align="optimal", fs="ext4", label="root", flags=[], name="Root Partition", resize="false", state="present", start="1025MiB", end="500GiB", number="3", unit="GiB"),
        ]
    )

    assert len(disk.partitions) == 3
    assert isinstance(disk.partitions[0], Partition)
    assert isinstance(disk.partitions[1], Partition)
    assert isinstance(disk.partitions[2], Partition)

def test_creating_efi_partition_through_ordinary_partition_with_invalid_mandatory_field_raises_validation_error():
    with pytest.raises(ValueError) as e:
        disk = Disk(
            device="/dev/sda",
            size="500GiB",
            partitions=[
                Partition(type="efi", align="optimal", fs="fat32", label="gpt", flags=['esp'], name="EFI System", resize="false", state="present", start="1MiB", end="512MiB", number="1", unit="MiB"), # Missing 'boot' flag
                Partition(type="swap", align="optimal", fs="linux-swap", label="swap", flags=['swap'], name="Swap", resize="false", state="present", start="513MiB", end="1024MiB", number="2", unit="MiB"),
                Partition(type="general", align="optimal", fs="ext4", label="root", flags=[], name="Root Partition", resize="false", state="present", start="1025MiB", end="500GiB", number="3", unit="GiB"),
            ]
        )

    assert "Flags must include both 'boot' and 'esp'" in str(e.value)

def test_creating_swap_efi_and_root_partitions_using_ordinary_partitions_with_additional_partitions_succeeds():
    disk = Disk(
        device="/dev/sda",
        size="500GiB",
        partitions=[
            Partition(type="efi", align="optimal", fs="fat32", label="gpt", flags=['boot', 'esp'], name="EFI System", resize="false", state="present", start="1MiB", end="512MiB", number="1", unit="MiB"),
            Partition(type="swap", align="optimal", fs="linux-swap", label="swap", flags=['swap'], name="Swap", resize="false", state="present", start="513MiB", end="1024MiB", number="2", unit="MiB"),
            Partition(type="general", align="optimal", fs="ext4", label="root", flags=[], name="Root Partition", resize="false", state="present", start="1025MiB", end="500GiB", number="3", unit="GiB"),
            Partition(type="general", align="optimal", fs="ext4", label="home", flags=[], name="Home Partition", resize="false", state="present", start="500GiB", end="1000GiB", number="4", unit="GiB"),
        ]
    )

    assert len(disk.partitions) == 4
    assert isinstance(disk.partitions[0], Partition)
    assert isinstance(disk.partitions[1], Partition)
    assert isinstance(disk.partitions[2], Partition)
    assert isinstance(disk.partitions[3], Partition)

def test_multiple_swap_partitions_raises_validation_error():
    with pytest.raises(ValueError) as e:
        disk = Disk(
            device="/dev/sda",
            size="500GiB",
            partitions=[
                EFIPartition(start="1MiB", end="512MiB", number="1", unit="MiB"),
                SwapPartition(start="513MiB", end="1024MiB", number="2", unit="MiB"),
                SwapPartition(start="1025MiB", end="1536MiB", number="3", unit="MiB"),
                RootPartition(start="1537MiB", end="500GiB", number="4", unit="GiB", fs="ext4"),
            ]
        )

    assert "There can be at most one Swap partition" in str(e.value)

def test_ansible_with_valid_data():
    with patch("os.path.isfile", return_value=True):
        ansible = Ansible(
            host="example-host",
            port=22,
            user="admin",
            inventory=["192.168.1.49", "10.0.0.1"],
            private_key="/path/to/private_key.pem",
            playbook="/path/to/playbook.yml"
        )
    assert ansible.host == "example-host"
    assert ansible.port == 22
    assert ansible.user == "admin"
    assert ansible.inventory == ["192.168.1.49", "10.0.0.1"]
    assert ansible.private_key == "/path/to/private_key.pem"
    assert ansible.playbook == "/path/to/playbook.yml"

def test_ansible_with_valid_ip_address_as_host():
    with patch("os.path.isfile", return_value=True):
        ansible = Ansible(
            host="192.168.1.1",
            port=22,
            user="admin",
            inventory=["192.168.1.49", "10.0.0.1"],
            private_key="/path/to/private_key.pem",
            playbook="/path/to/playbook.yml"
        )
    assert ansible.host == "192.168.1.1"
    assert ansible.port == 22
    assert ansible.user == "admin"
    assert ansible.inventory == ["192.168.1.49", "10.0.0.1"]
    assert ansible.private_key == "/path/to/private_key.pem"
    assert ansible.playbook == "/path/to/playbook.yml"

def test_invalid_host_format_raises_validation_error():
    with patch("os.path.isfile", return_value=True):
        with pytest.raises(ValidationError) as e:
            Ansible(
                host="invalid_host!@#",
                port=22,
                user="admin",
                inventory=["192.168.1.49"],
                private_key="/path/to/private_key.pem",
                playbook="/path/to/playbook.yml"
            )
    assert "Invalid host format" in str(e.value)

def test_invalid_ip_in_inventory_raises_validation_error():
    with patch("os.path.isfile", return_value=True):
        with pytest.raises(ValidationError) as e:
            Ansible(
                host="example-host",
                port=22,
                user="admin",
                inventory=["192.168.1.49", "invalid_ip"],
                private_key="/path/to/private_key.pem",
                playbook="/path/to/playbook.yml"
            )
    assert "Invalid IP address: invalid_ip" in str(e.value)

def test_nonexistent_private_key_raises_validation_error():
    with patch("os.path.isfile", side_effect=lambda x: x != "/path/to/nonexistent_key.pem"):
        with pytest.raises(ValidationError) as e:
            Ansible(
                host="example-host",
                port=22,
                user="admin",
                inventory=["192.168.1.49"],
                private_key="/path/to/nonexistent_key.pem",
                playbook="/path/to/playbook.yml"
            )
    assert "Private key file not found" in str(e.value)

def test_nonexistent_playbook_raises_validation_error():
    with patch("os.path.isfile", side_effect=lambda x: x != "/path/to/nonexistent_playbook.yml"):
        with pytest.raises(ValidationError) as e:
            Ansible(
                host="example-host",
                port=22,
                user="admin",
                inventory=["192.168.1.49"],
                private_key="/path/to/private_key.pem",
                playbook="/path/to/nonexistent_playbook.yml"
            )
    assert "Playbook file not found" in str(e.value)

def test_ansible_with_empty_inventory_raises_validation_error():
    with patch("os.path.isfile", return_value=True):
        with pytest.raises(ValidationError) as e:
            Ansible(
                host="example-host",
                port=22,
                user="admin",
                inventory=[],
                private_key="/path/to/private_key.pem",
                playbook="/path/to/playbook.yml"
            )
    assert "Inventory list must contain at least one entry" in str(e.value)

def test_ansible_with_invalid_port_raises_validation_error():
    with patch("os.path.isfile", return_value=True):
        with pytest.raises(ValidationError) as e:
            Ansible(
                host="example-host",
                port=65536,
                user="admin",
                inventory=["192.168.1.49"],
                private_key="/path/to/private_key.pem",
                playbook="/path/to/playbook.yml"
            )
    assert "Port must be between 0 and 65535" in str(e.value)

def test_ansible_with_valid_and_invalid_inventory():
    with patch("os.path.isfile", return_value=True):
        # Valid
        ansible = Ansible(
            host="example-host",
            port=22,
            user="admin",
            inventory=["192.168.1.49"],
            private_key="/path/to/private_key.pem",
            playbook="/path/to/playbook.yml"
        )
        assert ansible.inventory == ["192.168.1.49"]

        # Invalid
        with pytest.raises(ValidationError) as e:
            Ansible(
                host="example-host",
                port=22,
                user="admin",
                inventory=["invalid-ip"],
                private_key="/path/to/private_key.pem",
                playbook="/path/to/playbook.yml"
            )
        assert "Invalid IP address: invalid-ip" in str(e.value)

def test_ansible_with_nonexistent_private_key_and_playbook():
    with patch("os.path.isfile", side_effect=lambda x: x not in ["/path/to/nonexistent_key.pem", "/path/to/nonexistent_playbook.yml"]):
        with pytest.raises(ValidationError) as e:
            Ansible(
                host="example-host",
                port=22,
                user="admin",
                inventory=["192.168.1.49"],
                private_key="/path/to/nonexistent_key.pem",
                playbook="/path/to/nonexistent_playbook.yml"
            )
    assert "Private key file not found" in str(e.value)
    assert "Playbook file not found" in str(e.value)

def test_ansible_with_invalid_host_and_ip_raises_validation_error():
    with patch("os.path.isfile", return_value=True):
        with pytest.raises(ValidationError) as e:
            Ansible(
                host="invalid_host!@#",
                port=22,
                user="admin",
                inventory=["invalid_ip"],
                private_key="/path/to/private_key.pem",
                playbook="/path/to/playbook.yml"
            )
    assert "Invalid host format" in str(e.value)
    assert "Invalid IP address: invalid_ip" in str(e.value)

def test_user_with_valid_data():
    user = User(
        username="user1",
        password="password1",
        groups=["sudo", "users"],
        shell="/bin/bash"
    )
    assert user.username == "user1"
    assert user.password == "password1"
    assert user.groups == ["sudo", "users"]
    assert user.shell == "/bin/bash"

def test_invalid_username_raises_validation_error():
    with pytest.raises(ValidationError) as e:
        User(
            username="invalid user!",
            password="password1",
            groups=["sudo", "users"],
            shell="/bin/bash"
        )
    assert "Username must be alphanumeric" in str(e.value)

def test_empty_password_raises_validation_error():
    with pytest.raises(ValidationError) as e:
        User(
            username="user1",
            password="",
            groups=["sudo", "users"],
            shell="/bin/bash"
        )
    assert "Password cannot be empty" in str(e.value)

def test_invalid_group_name_raises_validation_error():
    with pytest.raises(ValidationError) as e:
        User(
            username="user1",
            password="password1",
            groups=["sudo", "invalid group!"],
            shell="/bin/bash"
        )
    assert "Group names must be alphanumeric" in str(e.value)

def test_shell_not_absolute_path_raises_validation_error():
    with pytest.raises(ValidationError) as e:
        User(
            username="user1",
            password="password1",
            groups=["sudo", "users"],
            shell="bin/bash"
        )
    assert "Shell must be an absolute path" in str(e.value)

def test_user_with_valid_and_invalid_groups():
    user = User(
        username="user1",
        password="password1",
        groups=["sudo", "users"],
        shell="/bin/bash"
    )
    assert user.groups == ["sudo", "users"]

    with pytest.raises(ValidationError) as e:
        User(
            username="user1",
            password="password1",
            groups=["sudo", "invalid group!"],
            shell="/bin/bash"
        )
    assert "Group names must be alphanumeric" in str(e.value)

def test_user_with_invalid_username_and_shell_raises_validation_error():
    with pytest.raises(ValidationError) as e:
        User(
            username="invalid user!",
            password="password1",
            groups=["sudo", "users"],
            shell="bin/bash"
        )
    assert "Username must be alphanumeric" in str(e.value)
    assert "Shell must be an absolute path" in str(e.value)
