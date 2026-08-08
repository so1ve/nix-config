{
  config,
  inputs,
  lib,
  ...
}:

{
  ray.features."system/nix" = {
    nixos = {
      nixpkgs.overlays = [ inputs.nur.overlays.default ];

      programs = {
        nh.enable = true;
        nix-ld.enable = true;
      };

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
