from pydantic import BaseModel, field_validator
from typing import List, Optional

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
    min: str
    max: str
    fs: str
    flags: List[str] = []

    @field_validator('min', 'max')
    @classmethod
    def validate_partition_size(cls, v):
        return validate_size(v)

class Disk(BaseModel):
    device: str
    size: str
    partitions: List[Partition]

    @field_validator('partitions')
    @classmethod
    def validate_partitions(cls, partitions):
        for i in range(1, len(partitions)):
            prev_max = float(partitions[i-1].max[:-3] if partitions[i-1].max.endswith(('MiB', 'GiB')) else partitions[i-1].max[:-1])
            curr_min = float(partitions[i].min[:-3] if partitions[i].min.endswith(('MiB', 'GiB')) else partitions[i].min[:-1])
            if curr_min < prev_max:
                raise ValueError(f'Partition {i} min value must be equal to or greater than the previous partition max value')
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