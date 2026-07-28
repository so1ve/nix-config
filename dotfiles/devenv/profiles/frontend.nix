{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ray.devenv.frontend;
in
{
  imports = [ ./config.nix ];

  options.ray.devenv.frontend = {
    directory = lib.mkOption {
      type = lib.types.str;
      default = ".";
      description = "Directory containing package.json, relative to the project root.";
    };

    nodePackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nodejs_26;
      description = "Node.js package used to bootstrap Corepack.";
    };
  };

  config = {
    env.NVIM_VUE_TYPESCRIPT_PLUGIN_PATH = "${pkgs.vue-language-server}/lib/language-tools/packages/language-server";

    languages.javascript = {
      enable = true;
      inherit (cfg) directory;
      package = cfg.nodePackage;

      # vtsls is provided below; do not add typescript-language-server too.
      lsp.enable = false;
    };

    packages = [
      (pkgs.corepack.override { nodejs-slim = cfg.nodePackage; })
      pkgs.vtsls
      pkgs.vue-language-server
    ];
  };
}
