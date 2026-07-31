{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ray.devenv.frontend;
  projectRoot = /. + config.devenv.root;
  projectDirectory = projectRoot + "/${cfg.directory}";
  projectNodeVersion = builtins.tryEval (
    inputs.node-overlay.lib.nodeVersionFromProject projectDirectory
  );
  nodePackage =
    if projectNodeVersion.success then
      pkgs.nodejs-bin.fromNodeVersion projectNodeVersion.value
    else
      pkgs.nodejs-bin.latest;
in
{
  imports = [ ./config.nix ];

  options.ray.devenv.frontend.directory = lib.mkOption {
    type = lib.types.str;
    default = ".";
    description = "JavaScript project directory, relative to the devenv root.";
  };

  config = {
    overlays = [ inputs.node-overlay.overlays.default ];

    env.NVIM_VUE_TYPESCRIPT_PLUGIN_PATH = "${pkgs.vue-language-server}/lib/language-tools/packages/language-server";

    languages.javascript = {
      enable = true;
      inherit (cfg) directory;
      package = lib.mkDefault nodePackage;
      corepack.enable = true;

      # vtsls is provided below; do not add typescript-language-server too.
      lsp.enable = false;
    };

    packages = [
      pkgs.vtsls
      pkgs.vue-language-server
    ];
  };
}
