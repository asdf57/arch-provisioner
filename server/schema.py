from pydantic import BaseModel, Field, conlist, constr
from typing import List, Dict, Optional

class Partition(BaseModel):
    min: str
    max: str
    fs: str
    flags: Optional[List[str]] = []

class Disk(BaseModel):
    device: str
    partitions: List[Partition]

class Ansible(BaseModel):
    host: str
    port: int
    user: str
    inventory: List[str]
    private_key: str
    playbook: str

class User(BaseModel):
    password: str
    groups: List[str]
    shell: str

class Config(BaseModel):
    ansible: Optional[Ansible] = None
    disk: Optional[Disk] = None
    root_password: str
    hostname: str
    locale: str
    users: Optional[Dict[str, User]] = None
    packages: Optional[List[str]] = []
