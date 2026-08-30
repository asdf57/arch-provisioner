IMAGE_NAME ?= homelab
IMAGE_TAG ?= latest

-include $(ENV_FILE)

.PHONY: help build shell

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "  build  Build the provisioning image"

build:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .
