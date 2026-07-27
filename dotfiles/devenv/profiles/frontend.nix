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
    languages.javascript = {
      enable = true;
      directory = cfg.directory;
      package = cfg.nodePackage;
      corepack.enable = true;

      # Neovim provides vtsls in its wrapper. Do not add the module's default
      # typescript-language-server alongside it.
      lsp.enable = false;
    };
  };
}
