IMAGE_NAME ?= prov
IMAGE_TAG  ?= latest

.PHONY: build

build-image:
	@echo "Building docker image $(IMAGE_NAME):$(IMAGE_TAG)"
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

# all: build-image

nix-env:
	./scripts/nix_env.sh

