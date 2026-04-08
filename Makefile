IMAGE_NAME ?= prov
IMAGE_TAG  ?= latest
USER_ENV_FILE ?= .env
BOOTSTRAP_ENV_FILE ?= .env.runtime

-include $(BOOTSTRAP_ENV_FILE)
export

DOCKER_UNPRIV_BASE_OPTS = --rm -it \
	-w /homelab \
	--env-file $(BOOTSTRAP_ENV_FILE) \
	-v $(HOST_DATA_PATH):$(MOUNTED_DATA_PATH)

DOCKER_PRIV_OPTS = --rm -it \
	--privileged \
	--network host \
	-v /var/run/docker.sock:/var/run/docker.sock \
	-v /lib/modules:/lib/modules:ro \
	-v /proc:/proc \
	-v /sys:/sys \
	-v /dev:/dev \
	-w /homelab \
	--env-file $(BOOTSTRAP_ENV_FILE) \
	-v $(HOST_GIT_PROVISIONING_KEY_FILE):/etc/ssh/git_provisioning_key:ro \
	-v $(HOST_PROVISIONING_KEY_FILE):/etc/ssh/provisioning_key:ro \
	-v $(HOST_DROPLET_KEY_FILE):/etc/ssh/droplet_key:ro \
	-v $(HOST_GIT_PROVISIONING_KEY_FILE).pub:/etc/ssh/git_provisioning_key.pub:ro \
	-v $(HOST_PROVISIONING_KEY_FILE).pub:/etc/ssh/provisioning_key.pub:ro \
	-v $(HOST_DROPLET_KEY_FILE).pub:/etc/ssh/droplet_key.pub:ro \
	-v $(HOST_DATA_PATH):$(MOUNTED_DATA_PATH) \

.PHONY: help clean build-image _build-image build-and-upload _build-and-upload \
	provision _provision init-platform _init-platform init-platform-force _init-platform-force \
	priv-env _priv-env user-env _user-env add-servers _add-servers build-isos _build-isos \
	build-isos-force _build-isos-force render-env \
	create-homelab-group build-homelab-data-dir ensure-ssh-key

create-homelab-group:
	@if ! getent group homelab > /dev/null 2>&1; then \
		echo "Creating homelab group with GID $(HOMELAB_GID)"; \
		sudo groupadd -g $(HOMELAB_GID) homelab; \
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
	@echo ":: Ensuring $(HOST_DATA_PATH) exists and has correct permissions"
	@sudo mkdir -p $(HOST_DATA_PATH)
	@sudo chown root:homelab $(HOST_DATA_PATH)
	@sudo chmod 2775 $(HOST_DATA_PATH)

render-env:
	@./scripts/render_env.sh "$(USER_ENV_FILE)" "$(BOOTSTRAP_ENV_FILE)"

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

	@if [ ! -f $(HOST_DROPLET_KEY_FILE) ]; then \
		echo ":: Generating droplet SSH key at $(HOST_DROPLET_KEY_FILE)"; \
		mkdir -p $$(dirname $(HOST_DROPLET_KEY_FILE)); \
		ssh-keygen -t ed25519 -f $(HOST_DROPLET_KEY_FILE) -N "" -C "droplet-key"; \
		echo ":: SSH key generated for droplet access."; \
		cat $(HOST_DROPLET_KEY_FILE).pub; \
	else \
		echo ":: SSH key already exists at $(HOST_DROPLET_KEY_FILE)"; \
	fi

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "General:"
	@echo "  help             Show this help message"
	@echo "Targets:"
	@echo "  clean            Clean up generated files"
	@echo "  render-env       Generate .env.runtime from .env and detected host values"
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

build-image: render-env
	@$(MAKE) --no-print-directory _build-image

_build-image:
	@echo "Building docker image"
	docker build --build-arg DOCKER_GID=$$DOCKER_GID --build-arg HOMELAB_GID=$$HOMELAB_GID --build-arg CONCOURSE_VERSION=$$CONCOURSE_VERSION -t $(IMAGE_NAME):$(IMAGE_TAG) .

build-and-upload: render-env
	@$(MAKE) --no-print-directory _build-and-upload

_build-and-upload: _build-image
	docker tag $(IMAGE_NAME):$(IMAGE_TAG) registry.ryuugu.dev/$(IMAGE_NAME):$(IMAGE_TAG)
	docker push registry.ryuugu.dev/$(IMAGE_NAME):$(IMAGE_TAG)

provision: render-env
	@$(MAKE) --no-print-directory _provision

_provision: _build-image
	docker run $(DOCKER_UNPRIV_BASE_OPTS) $(IMAGE_NAME):$(IMAGE_TAG) \
		bash -c "ansible-playbook -i inventory/inventory.yml ansible/plays/provision.yml -e should_wipe=true"

init-platform: render-env
	@$(MAKE) --no-print-directory _init-platform

_init-platform: create-homelab-group build-homelab-data-dir ensure-ssh-key _build-image
	docker run $(DOCKER_PRIV_OPTS) $(IMAGE_NAME):$(IMAGE_TAG) \
		bash -lc "ansible-playbook -i inventory/inventory.yml ansible/plays/init.yml --tags build"

init-platform-force: render-env
	@$(MAKE) --no-print-directory _init-platform-force

_init-platform-force: create-homelab-group build-homelab-data-dir ensure-ssh-key _build-image
	docker run $(DOCKER_PRIV_OPTS) $(IMAGE_NAME):$(IMAGE_TAG) \
		bash -lc "ansible-playbook -i inventory/inventory.yml ansible/plays/init.yml"

priv-env: render-env
	@$(MAKE) --no-print-directory _priv-env

_priv-env: create-homelab-group build-homelab-data-dir ensure-ssh-key _build-image
	docker run $(DOCKER_PRIV_OPTS) $(IMAGE_NAME):$(IMAGE_TAG) bash --login

user-env: render-env
	@$(MAKE) --no-print-directory _user-env

_user-env: _build-image
	docker run $(DOCKER_UNPRIV_BASE_OPTS) $(IMAGE_NAME):$(IMAGE_TAG) bash --login

add-servers: render-env
	@$(MAKE) --no-print-directory _add-servers

_add-servers: _build-image
	docker run $(DOCKER_UNPRIV_BASE_OPTS) $(IMAGE_NAME):$(IMAGE_TAG) \
		bash -lc "ansible-playbook -i inventory/inventory.yml ansible/plays/add_servers.yml"

build-isos: render-env
	@$(MAKE) --no-print-directory _build-isos

_build-isos: build-homelab-data-dir ensure-ssh-key _build-image
	docker run $(DOCKER_UNPRIV_BASE_OPTS) $(IMAGE_NAME):$(IMAGE_TAG) \
		bash -lc "ansible-playbook -i inventory/inventory.yml ansible/plays/build_isos.yml"

build-isos-force: render-env
	@$(MAKE) --no-print-directory _build-isos-force

_build-isos-force: build-homelab-data-dir ensure-ssh-key _build-image
	docker run $(DOCKER_PRIV_OPTS) $(IMAGE_NAME):$(IMAGE_TAG) \
		bash -lc "ansible-playbook -i inventory/inventory.yml ansible/plays/build_isos.yml -e force_build=true"
