from pydantic import BaseModel, ValidationError, field_validator
from typing import Dict, List, Literal, Tuple, Union, Optional

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

    @field_validator('start', 'end')
    @classmethod
    def validate_partition_size(cls, v):
        return validate_size(v)

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
        num_efi_partitions = len([p for p in partitions if isinstance(p, EFIPartition)])
        num_swap_partitions = len([p for p in partitions if isinstance(p, SwapPartition)])
        num_root_partitions = len([p for p in partitions if isinstance(p, RootPartition)])

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