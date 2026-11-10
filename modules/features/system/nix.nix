{
  config,
  inputs,
  lib,
  ...
}:

{
  ray.features."system/nix" = {
    options.settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Native nix.settings values overriding the feature defaults.";
    };

    nixos =
      { settings, ... }:
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
          min-free = 50 * 1024 * 1024 * 1024;
          max-free = 100 * 1024 * 1024 * 1024;
          trusted-users = [ "@wheel" ];
        }
        // config.ray.registry.nixCacheSettings
        // settings.settings;

        nix.gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 7d";
        };

        nixpkgs.config.allowUnfree = true;
      };
  };
}
