{
  config,
  inputs,
  ...
}:

{
  ray.features."system/nix" = {
    nixos = {
      nixpkgs.overlays = [ inputs.nur.overlays.default ];

      programs.nh.enable = true;

      nix.settings = {
        auto-optimise-store = true;
        experimental-features = [
          "nix-command"
          "flakes"
        ];
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
