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
	@echo "  clean            Clean up generated files"
	@echo "  init-platform    Initialize homelab infrastructure using Nix shell"
	@echo "  init-platform-force Force re-initialization of homelab infrastructure"
	@echo "  provision        Run ansible provisioning playbook inside Docker"
	@echo "  build-image      Build the Docker image for provisioning"
	@echo "  build-and-upload Build and upload the Docker image to the registry"
	@echo "  build-isos       Build installation ISOs for homelab devices"
	@echo "  build-isos-force Force rebuild of installation ISOs"
	@echo "  add-servers      Add new servers to the inventory and provision them"
	@echo "  priv-env        Start a privileged shell environment"
	@echo "  user-env        Start an unprivileged shell environment"
	@echo "Environments:"
	@echo "  nix-env          Start the Nix shell environment"
	@echo "  docker-env       Start a shell in a container environment"

clean:
	rm -rf inventory/

build-image:
	@echo "Building docker image"
	docker build --build-arg DOCKER_GID=$$DOCKER_GID --build-arg HOMELAB_GID=$$HOMELAB_GID --build-arg CONCOURSE_VERSION=$$CONCOURSE_VERSION -t $(IMAGE_NAME):$(IMAGE_TAG) .

build-and-upload: build-image
	docker tag $(IMAGE_NAME):$(IMAGE_TAG) registry.ryuugu.dev/$(IMAGE_NAME):$(IMAGE_TAG)
	docker push registry.ryuugu.dev/$(IMAGE_NAME):$(IMAGE_TAG)

provision:
	docker run $(DOCKER_UNPRIV_BASE_OPTS) $(IMAGE_NAME):$(IMAGE_TAG) \
		bash -c "ansible-playbook -i inventory/inventory.yml ansible/plays/provision.yml -e should_wipe=true"

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

add-servers: build-image
	docker run $(DOCKER_UNPRIV_BASE_OPTS) $(IMAGE_NAME):$(IMAGE_TAG) \
		bash -lc "ansible-playbook -i inventory/inventory.yml ansible/plays/add_servers.yml"

build-isos: build-homelab-data-dir build-image
	docker run $(DOCKER_UNPRIV_BASE_OPTS) $(IMAGE_NAME):$(IMAGE_TAG) \
		bash -lc "ansible-playbook -i inventory/inventory.yml ansible/plays/build_isos.yml"

build-isos-force: build-homelab-data-dir build-image
	docker run $(DOCKER_PRIV_OPTS) $(IMAGE_NAME):$(IMAGE_TAG) \
		bash -lc "ansible-playbook -i inventory/inventory.yml ansible/plays/build_isos.yml -e force_build=true"
