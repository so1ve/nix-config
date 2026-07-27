{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ray.devenv.go;
in
{
  options.ray.devenv.go.package = lib.mkOption {
    type = lib.types.package;
    default = pkgs.go;
    description = "Bootstrap Go package; go.mod may select a newer toolchain.";
  };

  config = {
    # devenv's languages.go module forces GOTOOLCHAIN=local. Keeping the Go
    # bootstrap package explicit lets go.mod's go/toolchain directives work.
    env.GOTOOLCHAIN = lib.mkDefault "auto";

    packages = with pkgs; [
      cfg.package
      delve
      go-task
    ];
  };
}
