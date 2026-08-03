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
  projectNodePackage = pkgs.node-bin.fromProject projectDirectory;
  projectBunPackage = pkgs.bun-bin.fromProject projectDirectory;
  projectDenoPackage = pkgs.deno-bin.fromProject projectDirectory;
  nodePackage = if projectNodePackage == null then pkgs.node-bin.latest else projectNodePackage;
in
{
  imports = [ ./config.nix ];

  options.ray.devenv.frontend.directory = lib.mkOption {
    type = lib.types.str;
    default = ".";
    description = "JavaScript project directory, relative to the devenv root.";
  };

  config = lib.mkMerge [
    {
      overlays = [ inputs.js-toolchain-overlay.overlays.default ];

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
    }

    (lib.mkIf (projectBunPackage != null) {
      languages.javascript.bun = {
        enable = true;
        package = lib.mkDefault projectBunPackage;
      };
    })

    (lib.mkIf (projectDenoPackage != null) {
      languages.deno = {
        enable = true;
        package = lib.mkDefault projectDenoPackage;
      };
    })
  ];
}
