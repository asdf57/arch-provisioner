import ipaddress
import os
from passlib.hash import sha512_crypt
from pydantic import BaseModel, field_validator, Field, field_serializer
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
LOCALES = [
    "en_US.UTF-8",
    "en_GB.UTF-8",
    "en_CA.UTF-8",
    "fr_FR.UTF-8",
    "fr_CA.UTF-8",
    "de_DE.UTF-8",
    "es_ES.UTF-8",
    "it_IT.UTF-8",
    "pt_BR.UTF-8",
    "pt_PT.UTF-8",
    "ru_RU.UTF-8",
    "zh_CN.UTF-8",
    "zh_TW.UTF-8",
    "ja_JP.UTF-8",
    "ko_KR.UTF-8",
    "nl_NL.UTF-8",
    "sv_SE.UTF-8",
    "da_DK.UTF-8",
    "fi_FI.UTF-8",
    "no_NO.UTF-8",
    "pl_PL.UTF-8",
    "cs_CZ.UTF-8",
    "hu_HU.UTF-8",
    "sk_SK.UTF-8",
    "el_GR.UTF-8",
    "tr_TR.UTF-8",
    "he_IL.UTF-8",
    "ar_SA.UTF-8",
    "hi_IN.UTF-8",
    "th_TH.UTF-8",
    "id_ID.UTF-8",
    "vi_VN.UTF-8",
    "ms_MY.UTF-8",
    "uk_UA.UTF-8",
    "ro_RO.UTF-8",
    "bg_BG.UTF-8",
    "hr_HR.UTF-8",
    "sr_RS.UTF-8",
    "sl_SI.UTF-8",
    "lt_LT.UTF-8",
    "lv_LV.UTF-8",
    "et_EE.UTF-8",
]

def validate_size(value: str) -> str:
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
    align: str = Field(default="optimal")
    flags: List[str] = Field(default_factory=list)
    fs: str = Field(...)
    label: str = Field(...)
    name: str = Field(...)
    number: int = Field(...)
    start: str = Field(...)
    end: str = Field(...)
    resize: str = Field(default="false")
    state: str = Field(default="present")
    unit: str = Field(...)

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

    class ConfigDict:
        populate_by_name = True

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

    @field_validator('number')
    def validate_partition_number(cls, v):
        if v <= 0:
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

    # Serializers
    # @field_serializer('flags', when_used='json')
    # def serialize_flags(v: List[str]) -> str:
    #     return ' '.join(v)

class EFIPartition(Partition):
    """
    Attributes that the USER must provide (not implemented defaults):
        - start
        - end
        - number
        - unit
    """
    type: Literal['efi'] = 'efi'
    fs: str = Field(default="fat32")
    label: str = Field(default="gpt")
    flags: List[str] = Field(default_factory=lambda: ['boot', 'esp'])
    name: str = Field(default="EFI System")

    @field_validator('flags')
    def validate_flags(cls, v):
        required_flags = {"boot", "esp"}
        if not required_flags.issubset(v):
            raise ValueError(f"Flags must include both 'boot' and 'esp'. Given: {v}")
        return v
    
    @field_validator('fs')
    def validate_fs(cls, v):
        if v != 'fat32':
            raise ValueError("EFI partition must have filesystem 'fat32'.")
        return

class SwapPartition(Partition):
    """
    Attributes that the USER must provide (not implemented defaults):
        - start
        - end
        - number
        - unit
    """
    type: Literal['swap'] = 'swap'
    fs: str = Field(default="linux-swap")
    label: str = Field(default="swap")
    flags: List[str] = Field(default_factory=lambda: ['swap'])
    name: str = Field(default="Swap")

    @field_validator('fs')
    def validate_fs(cls, v):
        if v != 'linux-swap':
            raise ValueError("Swap partition must have filesystem 'linux-swap'.")
        return

    @field_validator('flags')
    def validate_flags(cls, v):
        if "swap" not in v:
            raise ValueError("Flags must include 'swap'.")
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
    fs: str = Field(...)
    label: str = Field(default="root")
    flags: List[str] = Field(default_factory=list)
    name: str = Field(default="Root Partition")

def partition_factory(data: Union[dict, Partition]) -> Partition:
    if isinstance(data, EFIPartition) or isinstance(data, SwapPartition) or isinstance(data, RootPartition):
        return data

    if isinstance(data, Partition):
        partition_type = data.type
    else:
        partition_type = data.get('type')

    if partition_type == 'efi':
        return EFIPartition(**data.model_dump() if isinstance(data, Partition) else data)
    elif partition_type == 'swap':
        return SwapPartition(**data.model_dump() if isinstance(data, Partition) else data)
    elif partition_type == 'general':
        return RootPartition(**data.model_dump() if isinstance(data, Partition) else data)
    else:
        raise ValueError(f"Unsupported partition type: {partition_type}")

class Disk(BaseModel):
    device: str
    size: str
    partitions: List[Partition] = Field(..., default_factory=list)

    @field_validator('device')
    def validate_device(cls, v):
        if not v.startswith('/dev/'):
            raise ValueError(f"Device must start with '/dev/'. Given: {v}")
        return v

    @field_validator('size')
    def validate_size(cls, v):
        return validate_size(v)

    @field_validator('partitions', mode='before')
    def transform_partitions(cls, partitions):
        transformed_partitions = [partition_factory(partition) for partition in partitions]

        num_efi_partitions = sum(isinstance(p, EFIPartition) for p in transformed_partitions)
        num_swap_partitions = sum(isinstance(p, SwapPartition) for p in transformed_partitions)
        num_root_partitions = sum(isinstance(p, RootPartition) for p in transformed_partitions)

        print(f"EFI: {num_efi_partitions}, Swap: {num_swap_partitions}, Root: {num_root_partitions}, partitions: {partitions}\n\ntransformed: {transformed_partitions}")

        if num_efi_partitions != 1:
            raise ValueError("There must be exactly one EFI partition.")
        if num_root_partitions < 1:
            raise ValueError("There must be at least one root partition.")
        if num_swap_partitions > 1:
            raise ValueError("There can be at most one Swap partition.")

        return transformed_partitions

class Ansible(BaseModel):
    host: str
    port: int
    user: str
    inventory: List[str]
    private_key: str
    playbook: str

    @field_validator('host')
    def validate_host(cls, v):
        if not v.replace('.', '').replace('-', '').isalnum():
            raise ValueError('Invalid host format. Host must be alphanumeric with optional dots and hyphens.')
        return v

    @field_validator('port')
    def validate_port(cls, v):
        if not 0 <= v <= 65535:
            raise ValueError('Port must be between 0 and 65535')
        return v

    @field_validator('inventory')
    def validate_inventory(cls, v):
        if len(v) == 0:
            raise ValueError('Inventory list must contain at least one entry')

        for ip in v:
            try:
                ipaddress.ip_address(ip)
            except ValueError:
                raise ValueError(f"Invalid IP address: {ip}")
        return v

    @field_validator('private_key')
    def validate_private_key(cls, v):
        if not os.path.isfile(v):
            raise ValueError(f"Private key file not found: {v}")

        return v

    @field_validator('playbook')
    def validate_playbook(cls, v):
        if not os.path.isfile(v):
            raise ValueError(f"Playbook file not found: {v}")

        return v

    @field_serializer('inventory', when_used='json')
    def serialize_inventory(v: List[str]) -> str:
        return ','.join(v) + ','

class User(BaseModel):
    username: str
    password: str
    groups: List[str]
    shell: str

    @field_validator('username')
    def validate_username(cls, v):
        if not v.isalnum():
            raise ValueError('Username must be alphanumeric')
        return v

    @field_validator('password')
    def validate_password(cls, v):
        if not v:
            raise ValueError('Password cannot be empty')
        return v

    @field_validator('groups')
    def validate_groups(cls, v):
        if not all(group.isalnum() for group in v):
            raise ValueError('Group names must be alphanumeric')
        return v

    @field_validator('shell')
    def validate_shell(cls, v):
        if not v.startswith('/'):
            raise ValueError('Shell must be an absolute path')
        return v

    @field_serializer('password', when_used='json')
    def serialize_password(v: str) -> str:
        return sha512_crypt.hash(v)

class Config(BaseModel):
    ansible: Optional[Ansible] = None
    disk: Optional[Disk] = None
    root_password: str
    hostname: str
    locale: str
    users: Optional[List[User]] = None
    packages: List[str] = []

    @field_validator('root_password')
    def validate_root_password(cls, v):
        if not v:
            raise ValueError("Root password cannot be empty")
        return v

    @field_validator('hostname')
    def validate_hostname(cls, v):
        if not v.isalnum() and "-" not in v:
            raise ValueError("Hostname must be alphanumeric and can include hyphens")
        if len(v) > 63:
            raise ValueError("Hostname cannot exceed 63 characters")
        return v

    @field_validator('locale')
    def validate_locale(cls, v):
        if v not in LOCALES:
            raise ValueError("Invalid locale format. Expected format is 'en_US.UTF-8'")
        return v

    @field_validator('users')
    def validate_users(cls, v):
        if v is None or len(v) == 0:
            raise ValueError("Users list cannot be empty")
        return v

    @field_validator('packages')
    def validate_packages(cls, v):
        if any(not pkg for pkg in v):
            raise ValueError("Package names cannot be empty")
        return v