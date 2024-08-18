from pydantic import ValidationError
import pytest
from server.schema import EFIPartition, RootPartition, SwapPartition, validate_size, Partition, Disk

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
            EFIPartition(start="1MiB", end="512MiB", number="1", unit="MiB", flags=["boot", "esp", "additional"]),
            SwapPartition(start="513MiB", end="1024MiB", number="2", unit="MiB"),
            RootPartition(start="1025MiB", end="500GiB", number="3", unit="GiB", fs="ext4"),
        ]
    )

    assert disk.partitions[0].flags == ["boot", "esp", "additional"]

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
                EFIPartition(start="1MiB", end="512MiB", number="1", unit="MiB", flags=["boot", "invalid"]), # Invalid flag replacing 'esp'
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
            SwapPartition(start="513MiB", end="1024MiB", number="2", unit="MiB", flags=["swap", "additional"]),
            RootPartition(start="1025MiB", end="500GiB", number="3", unit="GiB", fs="ext4"),
        ]
    )

    assert disk.partitions[1].flags == ["swap", "additional"]

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
                SwapPartition(start="513MiB", end="1024MiB", number="2", unit="MiB", flags=["invalid"]),  # Invalid flag replacing 'swap'
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
            RootPartition(start="1025MiB", end="500GiB", number="3", unit="GiB", fs="ext4", flags=["a", "b"]),
        ]
    )

    assert disk.partitions[2].flags == ["a", "b"]
