IMAGE_NAME ?= prov
IMAGE_TAG  ?= latest

.PHONY: build

build-image:
	@echo "Building docker image $(IMAGE_NAME):$(IMAGE_TAG)"
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

nix-env:
	./scripts/nix_env.sh

nix-cleanup:
	rm alpine-minirootfs-3.22.0-x86_64.tar.gz
	rm -rf rootfs/
	rm -rf inventory/

docker-env:
	docker run -e VAULT_TOKEN=$$VAULT_TOKEN -e VAULT_ADDR=$$VAULT_ADDR -it $(IMAGE_NAME):$(IMAGE_TAG)
