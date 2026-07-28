{
  config,
  lib,
  pkgs,
  ...
}:

let
  projectRoot = /. + config.devenv.root;
  rustToolchainToml = projectRoot + "/rust-toolchain.toml";
  rustToolchain = projectRoot + "/rust-toolchain";
  toolchainFile =
    if builtins.pathExists rustToolchainToml then
      rustToolchainToml
    else if builtins.pathExists rustToolchain then
      rustToolchain
    else
      null;
in
{
  config = lib.mkMerge [
    {
      languages.rust = {
        enable = true;
        toolchainFile = lib.mkDefault toolchainFile;
      };

      packages = with pkgs; [
        pkg-config
        tombi
      ];
    }

    (lib.mkIf (config.languages.rust.toolchainFile == null) {
      languages.rust = {
        channel = lib.mkDefault "stable";
        components = lib.mkDefault [
          "rustc"
          "cargo"
          "clippy"
          "rustfmt"
          "rust-analyzer"
          "rust-src"
        ];
      };
    })
  ];
}
