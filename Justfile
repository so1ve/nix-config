host := "vesper"

default:
    @just --list

# Verify the generated flake before evaluating the remaining checks.
check: check-flake-file
    nix flake check . --no-build --show-trace --accept-flake-config

# Check that flake.nix is up to date with flake-file.nix.
check-flake-file:
    nix build .#checks.x86_64-linux.check-flake-file --no-link --accept-flake-config

# Build the system without activating it.
build:
    nh os build . -H {{ host }} --accept-flake-config

boot:
    nh os boot . -H {{ host }} --accept-flake-config

# Activate the configuration immediately.
switch:
    nh os switch . -H {{ host }} --accept-flake-config

# Format all Nix files with the formatter exported by the flake.
fmt:
    nix fmt --accept-flake-config

# Regenerate flake.nix from flake-file.nix.
write-flake:
    nix run .#write-flake --accept-flake-config

# Update all flake inputs.
update:
    nix flake update --accept-flake-config

# Keep at least 3 generations and recent gcroots, then collect all unreachable store paths.
gc period="7d" keep="3":
    nh clean all --keep {{ keep }} --keep-since {{ period }} --ask
