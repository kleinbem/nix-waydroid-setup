# Waydroid Setup for NixOS

default:
    @just --list

# Run the installer (requires sudo)
install:
    sudo nix run .

# Get Android ID for device registration
get-id:
    nix run .#get-id

# Check Waydroid/Magisk status
status:
    nix run .#status

# Uninstall patches
uninstall:
    nix run .#uninstall

# Enter development shell
dev:
    nix develop

# Lint shell scripts
lint:
    nix develop -c shellcheck scripts/*.sh

# Build assets
build:
    nix build .#assets

# Update flake inputs
update:
    nix flake update

# Check flake
check:
    nix flake check
