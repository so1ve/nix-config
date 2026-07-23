host := "vesper"

default:
    @just --list

# Evaluate the flake and its checks without building the system.
check:
    nix flake check . --no-build --show-trace

# Build the system without switching to it or creating a result symlink.
build:
    nix build .#nixosConfigurations.{{host}}.config.system.build.toplevel --no-link

# Activate the configuration immediately.
switch:
    sudo nixos-rebuild switch --flake .#{{host}}

# Format all Nix files with the formatter exported by the flake.
fmt:
    nix fmt

# Update all flake inputs.
update:
    nix flake update

# Delete generations older than 30 days, then collect unreachable store paths.
gc:
    sudo nix-collect-garbage --delete-older-than 30d
