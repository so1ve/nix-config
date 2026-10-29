set unstable
set lists

default:
    @just --list

# Verify the generated flake before evaluating the remaining checks.
check: check-flake-file
    nix flake check path:. --no-build --show-trace --accept-flake-config

# Check that flake.nix is up to date with flake-file.nix.
check-flake-file:
    nix build path:.#checks.x86_64-linux.check-flake-file --no-link --accept-flake-config

# Format all Nix files with the formatter exported by the flake.
fmt:
    nix fmt path:. --accept-flake-config

# Regenerate flake.nix from flake-file.nix.
write-flake:
    nix run path:.#write-flake --accept-flake-config

# Update all flake inputs.
update *input:
    nix flake update --accept-flake-config {{quote(input)}}

# Keep at least 3 generations and recent gcroots, then collect all unreachable store paths.
gc period="7d" keep="3":
    nh clean all --keep {{ keep }} --keep-since {{ period }} --ask
