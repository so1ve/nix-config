{
  config,
  inputs,
  lib,
  ...
}:

{
  ray.features."system/nix" = {
    nixos =
      { pkgs, ... }:
      {
        nixpkgs.overlays = [ inputs.nur.overlays.default ];

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
          min-free = lib.mkDefault (50 * 1024 * 1024 * 1024);
          max-free = lib.mkDefault (100 * 1024 * 1024 * 1024);
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
