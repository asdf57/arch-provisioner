IMAGE_NAME ?= homelab
IMAGE_TAG ?= latest

-include $(ENV_FILE)

.PHONY: help check build shell

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "  check  Validate shell script syntax"
	@echo "  build  Build the provisioning image"

check:
	bash -n profile.d/init.sh
	python3 -m unittest discover -s tests -p 'test_*.py'

build: check
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .
