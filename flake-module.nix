{
  config,
  inputs,
  lib,
  ...
}:

let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  serverHosts = lib.filterAttrs (_: host: host.isServer) config.ray.hosts.nixos;
  nixosConfigurations = lib.mapAttrs (
    _: host: config.ray.lib.mkNixosHost host
  ) config.ray.hosts.nixos;
  deploy.nodes = lib.mapAttrs (
    name: host: config.ray.lib.mkDeployNode host nixosConfigurations.${name}
  ) serverHosts;
in
{
  imports = [ (inputs.import-tree ./modules) ];

  _module.args.images = lib.mapAttrs (name: _: (import (./images + "/${name}/source.nix")).image) (
    builtins.readDir ./images
  );

  flake-file.outputs-schema.options = {
    checks = lib.mkOption {
      type = lib.types.lazyAttrsOf (lib.types.lazyAttrsOf lib.types.package);
    };
    packages = lib.mkOption {
      type = lib.types.lazyAttrsOf (lib.types.lazyAttrsOf lib.types.package);
    };
  };

  outputs = _: {
    inherit nixosConfigurations deploy;
    checks.${system} =
      lib.mapAttrs (_: nixos: nixos.config.system.build.toplevel) nixosConfigurations
      // inputs.deploy-rs.lib.${system}.deployChecks deploy
      // {
        feature-registry =
          let
            failures = import ./tests/feature-registry.nix { inherit lib; };
          in
          assert lib.assertMsg (failures == [ ]) (builtins.toJSON failures);
          pkgs.runCommand "feature-registry-tests" { } "touch $out";
      };
    formatter.${system} = pkgs.nixfmt-tree;
    packages.${system} = {
      deploy-rs = inputs.deploy-rs.packages.${system}.default;
      update = pkgs.writeShellApplication {
        name = "update-images";
        runtimeInputs = [ inputs.nix-repin.packages.${system}.default ];
        text = ''
          exec nix-repin --packages-root images "$@"
        '';
      };
    };
  };
}
