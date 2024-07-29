from pydantic import BaseModel, field_validator
from typing import List, Optional
import re

class Partition(BaseModel):
    min: str
    max: str
    fs: str
    flags: Optional[List[str]] = []

    @field_validator('min', 'max', mode='after')
    def check_format(cls, value):
        if not re.match(r'^\d+(MiB|GiB|%)$', value):
            raise ValueError(f'{value} must end with MiB, GiB, or %')
        return value

    @field_validator('min', 'max', mode='after')
    def check_percentage(cls, value):
        if value.endswith('%'):
            value_int = int(value[:-1])
            if not (0 <= value_int <= 100):
                raise ValueError('Percentage value must be between 0 and 100')
        return value

class Disk(BaseModel):
    device: str
    size: str
    partitions: List[Partition]

    @field_validator('partitions', mode='after')
    def check_partitions_order(cls, partitions):
        for i in range(1, len(partitions)):
            prev_max = int(partitions[i-1].max[:-3]) if partitions[i-1].max.endswith(('MiB', 'GiB')) else int(partitions[i-1].max[:-1])
            curr_min = int(partitions[i].min[:-3]) if partitions[i].min.endswith(('MiB', 'GiB')) else int(partitions[i].min[:-1])
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
    packages: Optional[List[str]] = []