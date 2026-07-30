{
  config,
  inputs,
  ...
}:

{
  ray.features."core/nix" = {
    nixos = {
      nixpkgs.overlays = [ inputs.nur.overlays.default ];

      nix.settings = {
        auto-optimise-store = true;
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        trusted-users = [ "@wheel" ];
      }
      // config.ray.lib.nixCacheSettings;

      nix.gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 7d";
      };

      nixpkgs.config.allowUnfree = true;
    };
  };
}
