from pydantic import BaseModel, field_validator
from typing import List, Literal, Tuple, Union, Optional

FLAGS = [
    "bios_grub",
    "legacy_boot",
    "bls_boot",
    "boot",
    "msftdata",
    "msftres",
    "irst",
    "esp",
    "chromeos_kernel",
    "lba",
    "root",
    "linux-home",
    "swap",
    "hidden",
    "raid",
    "LVM",
    "PALO",
    "PREP",
    "DIAG"
]

FILE_SYSTEMS = [
    "btrfs",
    "ext2",
    "ext3",
    "ext4",
    "fat16",
    "fat32",
    "hfs",
    "hfs+",
    "linux-swap",
    "ntfs",
    "reiserfs",
    "udf",
    "xfs"
]


def validate_size(value: str) -> str:
    print(value)
    if not value.endswith(('%', 'MiB', 'GiB')):
        raise ValueError(f'{value} must end with MiB, GiB, or %')

    numeric_part = value[:-1] if value.endswith('%') else value[:-3]
    try:
        size = float(numeric_part)
        if value.endswith('%') and not 0 <= size <= 100:
            raise ValueError('Percentage value must be between 0 and 100')
    except ValueError:
        raise ValueError(f'Invalid numeric value: {value}')

    return value

class Partition(BaseModel):
    type: Literal['efi', 'swap', 'general']
    align: str
    flags: List[str]
    fs: str
    label: str
    name: str
    number: str
    start: str
    end: str
    type: str
    resize: str
    state: str
    unit: str

    """
    Partition rules:
    (1) Requires the unordered sequence: EFI, [SWAP], ROOT+
        (1.1) EFI partition
            (1.1.1) Must exist
        (1.2) SWAP partition
            (1.2.1) Optional
        (1.3) ROOT partition
            (1.3.1) Must exist
            (1.3.2) One or more ROOT partitions can exist.
    """

    @field_validator('type')
    def validate_partition_type(cls, v):
        if v not in ['efi', 'swap', 'general']:
            raise ValueError(f"Invalid partition type: {v}")
        return v

    @field_validator('align')
    def validate_partition_align(cls, v):
        if v not in ['cylinder', 'minimal', 'optimal', 'none', 'undefined']:
            raise ValueError(f"Invalid alignment: {v}")
        return v

    @field_validator('flags')
    def validate_partition_flags(cls, v):
        if not all(flag in FLAGS for flag in v):
            raise ValueError(f"Invalid flags: {v}")

        return v

    @field_validator('fs')
    def validate_partition_fs(cls, v):
        if v not in FILE_SYSTEMS:
            raise ValueError(f"Invalid filesystem: {v}")
        return v

    @field_validator('label')
    def validate_partition_label(cls, v):
        max_length = 16

        # Check if label length is within the limit
        if len(v) > max_length:
            raise ValueError(f"Label length must be less than or equal to {max_length} characters. Given: {v}")

        # Check if all characters in the label are valid
        if not all(char.isalnum() or char in '._-' for char in v):
            raise ValueError(f"Label must only contain alphanumeric characters, '.', '_', or '-'. Given: {v}")

        return v

    @field_validator('name')
    def validate_partition_name(cls, v):
        max_length = 32

        # Check if name length is within the limit
        if len(v) > max_length:
            raise ValueError(f"Name length must be less than or equal to {max_length} characters. Given: {v}")

        # Check if all characters in the name are valid
        if not all(char.isalnum() or char in ' ._-' for char in v):
            raise ValueError(f"Name must only contain alphanumeric characters, '.', '_', or '-'. Given: {v}")

        return v

    @field_validator('number')
    def validate_partition_number(cls, v):
        if not v.isdigit():
            raise ValueError(f"Partition number must be a positive integer. Given: {v}")

        return v

    @field_validator('start', 'end')
    def validate_partition_size(cls, v):
        return validate_size(v)

    @field_validator('resize')
    def validate_partition_resize(cls, v):
        if v not in ['true', 'false']:
            raise ValueError(f"Resize must be either 'true' or 'false'. Given: {v}")

        return v

    @field_validator('state')
    def validate_partition_state(cls, v):
        if v not in ['present', 'absent', 'info']:
            raise ValueError(f"State must be either 'present', 'absent', or 'info'. Given: {v}")

        return v

    @field_validator('unit')
    def validate_partition_unit(cls, v):
        if v not in ['MiB', 'GiB', '%']:
            raise ValueError(f"Invalid unit: {v}")

        return v

class EFIPartition(Partition):
    """
    Attributes that the USER must provide (not implemented defaults):
        - start
        - end
        - number
        - unit
    """
    type: Literal['efi'] = 'efi'
    align: str = "optimal"
    fs: Literal['fat32'] = "fat32"
    label: str = "gpt"
    flags: List[str] = ['boot', 'esp']
    name: str = "EFI System"
    resize: str = "false"
    state: str = "present"

    @field_validator('flags')
    def validate_flags(cls, v):
        required_flags = {"boot", "esp"}
        if not required_flags.issubset(v):
            raise ValueError(f"Flags must include both 'boot' and 'esp'. Given: {v}")
        return v

class SwapPartition(Partition):
    """
    Attributes that the USER must provide (not implemented defaults):
        - start
        - end
        - number
        - unit
    """
    type: Literal['swap'] = 'swap'
    align: str = "optimal"
    fs: Literal['linux-swap'] = "linux-swap"
    label: str = "swap"
    flags: List[str] = ['swap']
    name: str = "Swap"
    resize: str = "false"
    state: str = "present"

    @field_validator('flags')
    def validate_flags(cls, v):
        required_flags = {"swap"}
        if not required_flags.issubset(v):
            raise ValueError(f"Flags must include 'swap'. Given: {v}")
        return v

class RootPartition(Partition):
    """
    Attributes that the USER must provide (not implemented defaults):
        - start
        - end
        - number
        - unit
        - fs
    """
    type: Literal['general'] = 'general'
    align: str = "optimal"
    label: str = "root"
    flags: List[str] = []
    name: str = "Root Partition"
    resize: str = "false"
    state: str = "present"    

class Disk(BaseModel):
    device: str
    size: str
    partitions: List[Partition]

    @field_validator('partitions')
    def check_partition_requirements(cls, partitions):
        total_partitions = []

        """
        Partition types can be created in two separate ways:
        (1) As a Partition object
        (2) As the explicit partition object (EFIPartition, SwapPartition, RootPartition)

        This function therefore needs to be able to validate both types of partition objects
        when defining either the 'efi' or 'swap' partition types. To do this, we'll loop through
        each partition and if we detect any general Partition objects with type 'efi' or 'swap',
        we'll attempt to convert them to their respective explicit partition objects.
        """

        # Convert any Partition objects with type 'efi' or 'swap' to their respective explicit partition objects
        for partition in partitions:
            if partition.type == 'efi' and not isinstance(partition, EFIPartition):
                total_partitions.append(EFIPartition(**partition.model_dump()))
            elif partition.type == 'swap' and not isinstance(partition, SwapPartition):
                total_partitions.append(SwapPartition(**partition.model_dump()))
            elif partition.type == 'general' and not isinstance(partition, RootPartition):
                total_partitions.append(RootPartition(**partition.model_dump()))
            else:
                total_partitions.append(partition)

        # Calculate the number of EFI, Swap, and General partitions
        num_efi_partitions = len([p for p in total_partitions if isinstance(p, EFIPartition)])
        num_swap_partitions = len([p for p in total_partitions if isinstance(p, SwapPartition)])
        num_root_partitions = len([p for p in total_partitions if isinstance(p, RootPartition)])

        # Verify that the partition count requirements are met
        if num_efi_partitions != 1:
            raise ValueError("There must be exactly one EFI partition.")
        if num_root_partitions < 1:
            raise ValueError("There must be at least one root partition.")
        if num_swap_partitions > 1:
            raise ValueError("There can be at most one Swap partition.")

        return partitions

class Ansible(BaseModel):
    host: str
    port: int
    user: str
    inventory: List[str]
    private_key: str
    playbook: str

class User(BaseModel):
    username: str
    password: str
    groups: List[str]
    shell: str

class Config(BaseModel):
    ansible: Optional[Ansible] = None
    disk: Optional[Disk] = None
    root_password: str
    hostname: str
    locale: str
    users: Optional[List[User]] = None
    packages: List[str] = []