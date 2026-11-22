{
  config,
  inputs,
  lib,
  ...
}:

let
  collectInputs =
    seen: input:
    if !(builtins.isAttrs input) || !(input ? outPath) then
      seen
    else
      let
        key = builtins.unsafeDiscardStringContext input.outPath;
      in
      if seen ? ${key} then
        seen
      else
        builtins.foldl' collectInputs (seen // { ${key} = input.outPath; }) (
          if input ? inputs && builtins.isAttrs input.inputs then builtins.attrValues input.inputs else [ ]
        );

  flakeInputs = builtins.attrValues (
    builtins.foldl' collectInputs { } (
      builtins.attrValues (
        builtins.removeAttrs inputs [
          "self"
          "nix-config"
        ]
      )
    )
  );
in
{
  ray.features."system/nix" = {
    options = {
      keepFlakeInputs = lib.mkEnableOption "keeping external flake inputs as GC roots";

      settings = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Native nix.settings values overriding the feature defaults.";
      };
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
          inputs.firn.packages.${pkgs.stdenv.hostPlatform.system}.default
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

        system.extraDependencies = lib.optionals settings.keepFlakeInputs flakeInputs;

        nixpkgs.config.allowUnfree = true;
      };
  };
}
