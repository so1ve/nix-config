{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ray.devenv.rust;
in
{
  options.ray.devenv.rust.rustupPackage = lib.mkOption {
    type = lib.types.package;
    default = pkgs.rustup;
    description = "Rustup package used to honor the project's rust-toolchain file.";
  };

  config.packages = [
    cfg.rustupPackage
    pkgs.clang
    pkgs.pkg-config
  ];
}
