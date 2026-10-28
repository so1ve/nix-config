{
  config,
  inputs,
  lib,
  ...
}:

{
  ray.features."system/nix" = {
    options = {
      minFree = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 50 * 1024 * 1024 * 1024;
        description = "Free space in bytes below which Nix starts automatic garbage collection.";
      };
      maxFree = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 100 * 1024 * 1024 * 1024;
        description = "Target free space in bytes for automatic garbage collection.";
      };
    };

    nixos =
      settings:
      { pkgs, ... }:
      {
        programs = {
          nh.enable = true;
          nix-ld.enable = true;
        };

        environment.systemPackages = [
          inputs.nix-alien.packages.${pkgs.stdenv.hostPlatform.system}.nix-alien
        ];

        nix.settings = {
          auto-optimise-store = true;
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          min-free = settings.minFree;
          max-free = settings.maxFree;
          trusted-users = [ "@wheel" ];
        }
        // config.ray.registry.nixCacheSettings;

        nix.gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 7d";
        };

        nixpkgs.config.allowUnfree = true;
      };
  };
}
