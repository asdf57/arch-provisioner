import sys
import yaml
from git import Repo

def load_inventory_from_commit(commit, file_path="inventory.yml"):
    blob = commit.tree / file_path
    data = blob.data_stream.read()
    return yaml.safe_load(data)

def get_inv_diff(prev_inv: dict, cur_inv: dict):
    to_create = []
    to_delete = []

    print(f"Previous inventory: {prev_inv}")
    print(f"Current inventory: {cur_inv}")

    prev_hosts = prev_inv.get("hosts", [])
    cur_hosts = cur_inv.get("hosts", [])

    for host in prev_hosts:
        if host not in cur_hosts:
            to_delete.append(host)

    for host in cur_hosts:
        if host not in prev_hosts:
            to_create.append(host)

    print("To delete:", to_delete)
    print("To create:", to_create)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("diff_checker.py <inventory repo path>")
        sys.exit(1)

    repo = Repo(sys.argv[1])

    # Get the last two commits on HEAD
    commits = list(repo.iter_commits("HEAD", max_count=2))
    latest_commit, previous_commit = commits[0], commits[1]

    # Load inventory.yml from each commit
    cur_inv = load_inventory_from_commit(latest_commit, "inventory.yml")
    prev_inv = load_inventory_from_commit(previous_commit, "inventory.yml")

    get_inv_diff(prev_inv, cur_inv)
