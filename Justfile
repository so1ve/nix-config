host := "vesper"

default:
    @just --list

# Verify the generated flake before evaluating the remaining checks.
check: check-flake-file
    nix flake check . --no-build --show-trace --accept-flake-config

# Check that flake.nix is up to date with flake-file.nix.
check-flake-file:
    nix build .#checks.x86_64-linux.check-flake-file --no-link --accept-flake-config

# Build the system without switching to it or creating a result symlink.
build:
    nix build .#nixosConfigurations.{{ host }}.config.system.build.toplevel --no-link --accept-flake-config

boot:
    sudo nixos-rebuild boot --flake .#{{ host }} --accept-flake-config

# Activate the configuration immediately.
switch:
    sudo nixos-rebuild switch --flake .#{{ host }} --accept-flake-config

# Format all Nix files with the formatter exported by the flake.
fmt:
    nix fmt --accept-flake-config

# Regenerate flake.nix from flake-file.nix.
write-flake:
    nix run .#write-flake --accept-flake-config

# Update all flake inputs.
update:
    nix flake update --accept-flake-config

# Delete generations older than 30 days, then collect unreachable store paths.
gc:
    sudo nix-collect-garbage --delete-older-than 30d
