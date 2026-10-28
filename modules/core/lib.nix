{
  config,
  inputs,
  lib,
  ...
}:

{
  config.ray.lib = {
    mkNixosHost = import ../../lib/mk-nixos-host.nix {
      inherit config inputs lib;
    };
    mkDeployNode = import ../../lib/mk-deploy-node.nix { inherit inputs; };
  };
}
