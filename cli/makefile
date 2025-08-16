.PHONY: build clean

BINARY_NAME := hlcli
SRC := ./main.go

all: build

build:
	@echo "Building the CLI application..."
	go build -o $(BINARY_NAME) $(SRC)
	@mkdir -p ~/.local/bin
	@echo "Build complete."

install: build
	@echo "Installing the CLI application to ~/.local/bin..."
	cp $(BINARY_NAME) ~/.local/bin/
	@chmod +x ~/.local/bin/$(BINARY_NAME)
	@echo "Installation complete. You can now run 'hlcli' from anywhere."

clean:
	@echo "Cleaning up build artifacts..."
	rm -f $(BINARY_NAME)
	@echo "Removing old binaries from ~/.local/bin/ ..."
	rm -f ~/.local/bin/hlcli
	@echo "Cleanup complete."

