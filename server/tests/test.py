import pytest
from server.schema import validate_size, Partition, Disk

def test_validate_size():
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

def test_partition():
    partition = Partition(min='10MiB', max='20MiB', fs='ext4')
    assert partition.min == '10MiB'
    assert partition.max == '20MiB'
    assert partition.fs == 'ext4'
    with pytest.raises(ValueError):
        Partition(min='10MB', max='5MiB', fs='ext4')
    with pytest.raises(ValueError):
        Partition(min='10MiB', max='20MB', fs='ext4')
    with pytest.raises(ValueError):
        Partition(min='10MB', max='20MB', fs='ext4')

def test_disk():
    disk = Disk(device='/dev/sda', size='100GiB', partitions=[
        Partition(min='0MiB', max='50MiB', fs='ext4'),
        Partition(min='50MiB', max='100MiB', fs='ext4')
    ])
    assert disk.device == '/dev/sda'
    assert disk.size == '100GiB'
    assert len(disk.partitions) == 2
    with pytest.raises(ValueError):
        Disk(device='/dev/sda', size='100GiB', partitions=[
            Partition(min='0MiB', max='50MiB', fs='ext4'),
            Partition(min='40MiB', max='100MiB', fs='ext4')
        ])