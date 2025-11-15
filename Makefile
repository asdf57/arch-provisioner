IMAGE_NAME ?= prov
IMAGE_TAG  ?= latest

include .env
export

DOCKER_UNPRIV_BASE_OPTS = --rm -it \
	-w /homelab \
	--env-file .env \
	-v $(HOST_DATA_PATH):$(MOUNTED_DATA_PATH)

DOCKER_PRIV_OPTS = --rm -it \
	--privileged \
	--network host \
	-v /var/run/docker.sock:/var/run/docker.sock \
	-v /proc:/proc \
	-v /sys:/sys \
	-v /dev:/dev \
	-w /homelab \
	--env-file .env \
	-v $(HOST_GIT_PROVISIONING_KEY_FILE):/etc/ssh/git_provisioning_key:ro \
	-v $(HOST_PROVISIONING_KEY_FILE):/etc/ssh/provisioning_key:ro \
	-v $(HOST_GIT_PROVISIONING_KEY_FILE).pub:/etc/ssh/git_provisioning_key.pub:ro \
	-v $(HOST_PROVISIONING_KEY_FILE).pub:/etc/ssh/provisioning_key.pub:ro \
	-v $(HOST_DATA_PATH):$(MOUNTED_DATA_PATH) \

.PHONY: help clean provision provision-nix build-image nix-cleanup init-platform metal-env nix-env docker-env ensure-ssh-key

create-homelab-group:
	@if ! getent group homelab > /dev/null 2>&1; then \
		echo "Creating homelab group with GID 2000"; \
		sudo groupadd -g 2000 homelab; \
	else \
		echo "Group 'homelab' already exists"; \
	fi

	@if ! id -nG $(USER) | grep -qw homelab; then \
		echo "Adding user $(USER) to homelab group"; \
		sudo usermod -aG homelab $(USER); \
	else \
		echo "User $(USER) is already in the homelab group"; \
	fi

build-homelab-data-dir: create-homelab-group
	@echo ":: Ensuring /srv/homelab directory exists and has correct permissions"
	@if [ ! -d "/srv/homelab" ]; then \
		sudo mkdir -p /srv/homelab; \
		sudo chown root:homelab /srv/homelab; \
		sudo chmod 2775 /srv/homelab; \
	fi

ensure-ssh-key:
	@if [ ! -f $(HOST_GIT_PROVISIONING_KEY_FILE) ]; then \
		echo ":: Generating Git provisioning SSH key at $(HOST_GIT_PROVISIONING_KEY_FILE)"; \
		mkdir -p $$(dirname $(HOST_GIT_PROVISIONING_KEY_FILE)); \
		ssh-keygen -t ed25519 -f $(HOST_GIT_PROVISIONING_KEY_FILE) -N "" -C "provisioning-key"; \
		echo ":: SSH key generated. Add the public key to your Git provider:"; \
		cat $(HOST_GIT_PROVISIONING_KEY_FILE).pub; \
	else \
		echo ":: SSH key already exists at $(HOST_GIT_PROVISIONING_KEY_FILE)"; \
	fi

	@if [ ! -f $(HOST_PROVISIONING_KEY_FILE) ]; then \
		echo ":: Generating device provisioning SSH key at $(HOST_PROVISIONING_KEY_FILE)"; \
		mkdir -p $$(dirname $(HOST_PROVISIONING_KEY_FILE)); \
		ssh-keygen -t ed25519 -f $(HOST_PROVISIONING_KEY_FILE) -N "" -C "provisioning-key"; \
		echo ":: SSH key generated. Will bake this into ISOs once built!"; \
		cat $(HOST_PROVISIONING_KEY_FILE).pub; \
	else \
		echo ":: SSH key already exists at $(HOST_PROVISIONING_KEY_FILE)"; \
	fi

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "General:"
	@echo "  help             Show this help message"
	@echo "Targets:"
	@echo "  provision        Run ansible provisioning playbook inside Docker"
	@echo "  provision-nix    Run ansible provisioning playbook inside Nix shell"
	@echo "  build-image      Build the Docker image for provisioning"
	@echo "  nix-cleanup      Remove temporary files and directories from Nix env"
	@echo "  init-platform    Initialize homelab infrastructure using Nix shell"
	@echo "Environments:"
	@echo "  nix-env          Start the Nix shell environment"
	@echo "  docker-env       Start a shell in a container environment"

clean:
	rm -rf inventory/

provision:
	docker run -e VAULT_TOKEN=$$VAULT_TOKEN -e VAULT_ADDR=$$VAULT_ADDR -it prov:latest bash -c "ansible-playbook -i inventory/inventory.yml ansible/plays/provision.yml --limit beelink -e vault_root_password=$VAULT_TOKEN -e should_wipe=true"

provision-nix:
	./scripts/nix_env.sh "ansible-playbook -i inventory/inventory.yml ansible/plays/provision.yml --limit beelink -e vault_root_password=$$VAULT_TOKEN -e should_wipe=true"

build-image:
	@echo "Building docker image $(IMAGE_NAME):$(IMAGE_TAG)"
	docker build --build-arg DOCKER_GID=$$DOCKER_GID --build-arg HOMELAB_GID=$$HOMELAB_GID -t $(IMAGE_NAME):$(IMAGE_TAG) .

init-platform: create-homelab-group build-homelab-data-dir ensure-ssh-key build-image
	docker run $(DOCKER_PRIV_OPTS) $(IMAGE_NAME):$(IMAGE_TAG) \
		bash -lc "ansible-playbook -i inventory/inventory.yml ansible/plays/init.yml --tags build"

init-platform-force: create-homelab-group build-homelab-data-dir ensure-ssh-key build-image
	docker run $(DOCKER_PRIV_OPTS) $(IMAGE_NAME):$(IMAGE_TAG) \
		bash -lc "ansible-playbook -i inventory/inventory.yml ansible/plays/init.yml"

priv-env: create-homelab-group build-homelab-data-dir ensure-ssh-key build-image
	docker run $(DOCKER_PRIV_OPTS) $(IMAGE_NAME):$(IMAGE_TAG) bash --login

user-env: build-image
	docker run $(DOCKER_UNPRIV_BASE_OPTS) $(IMAGE_NAME):$(IMAGE_TAG) bash --login

init-servers: build-image
	docker run $(DOCKER_UNPRIV_BASE_OPTS) $(IMAGE_NAME):$(IMAGE_TAG) \
		bash -lc "ansible-playbook -i inventory/inventory.yml ansible/plays/add_servers.yml"
