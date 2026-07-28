{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ray.devenv.zig;
in
{
  options.ray.devenv.zig.package = lib.mkOption {
    type = lib.types.package;
    default = pkgs.zig;
    description = "Zig compiler package.";
  };

  config.packages = [
    cfg.package
    pkgs.zls
  ];
}
