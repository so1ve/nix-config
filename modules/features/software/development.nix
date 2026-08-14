{
  ray.features."software/development" = {
    nixos =
      { pkgs, ... }:
      {
        documentation = {
          dev.enable = true;
          man = {
            enable = true;
            cache.enable = true;
          };
        };

        environment.systemPackages = with pkgs; [
          man-pages
          man-pages-posix
        ];
      };

    home =
      {
        config,
        inputs,
        lib,
        mkDotfilesSymlink,
        pkgs,
        ...
      }:
      let
        moduleRoot = "${config.xdg.configHome}/devenv/ray";
        script =
          builtins.replaceStrings
            [
              "__MODULE_ROOT__"
              "__GIT__"
              "__DIRENV__"
            ]
            [
              moduleRoot
              (lib.getExe pkgs.git)
              (lib.getExe pkgs.direnv)
            ]
            (builtins.readFile ./development/dev-env.js);
        devEnv = pkgs.writers.writeJSBin "dev-env" { } script;
      in
      {
        imports = [ inputs.direnv-instant.homeModules.direnv-instant ];

        home.packages = [
          devEnv
          pkgs.devenv
          pkgs.ni
        ];

        programs.direnv-instant.enable = true;

        xdg.configFile."devenv/ray".source = mkDotfilesSymlink {
          inherit config;
          name = "devenv";
        };
      };
  };
}
