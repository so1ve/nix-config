{
  ray.features."core/nix" = {
    nixos =
      { inputs, ... }:
      {
        nix.settings.experimental-features = [
          "nix-command"
          "flakes"
        ];

        nix.gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 30d";
        };

        nixpkgs = {
          config.allowUnfree = true;

          overlays = [
            (final: _prev: {
              unstable = import inputs.nixpkgs-unstable {
                system = final.stdenv.hostPlatform.system;
                inherit (final) config;
              };
            })
          ];
        };
      };
  };
}
