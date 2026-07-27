{
  config,
  lib,
  ...
}:

let
  nixosConfigurations = lib.mapAttrs (
    _: host: config.ray.lib.mkNixosHost host
  ) config.ray.hosts.nixos;
in
{
  systems = [ "x86_64-linux" ];

  flake = {
    inherit nixosConfigurations;

    nixosModules = config.ray.lib.moduleAttrsFor "nixos";
    homeModules = config.ray.lib.moduleAttrsFor "home";
  };

  perSystem =
    {
      pkgs,
      ...
    }:
    {
      checks = lib.mapAttrs (
        name: _: nixosConfigurations.${name}.config.system.build.toplevel
      ) config.ray.hosts.nixos;

      formatter = pkgs.nixfmt-tree;
    };
}
