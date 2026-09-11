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
          inputs.so1ve.packages.${pkgs.stdenv.hostPlatform.system}.cargo-pretty
          devEnv
          pkgs.devenv
          pkgs.ni
        ];

        programs.fish = {
          shellAbbrs = {
            cb = "cargo pretty build";
            cr = "cargo pretty run";
            ct = "cargo pretty test";
          };
          interactiveShellInit = ''
            ${lib.getExe' pkgs.ni "nr"} --completion-fish | source
          '';
        };

        programs.direnv-instant = {
          enable = true;
          settings.mux_delay = 30;
        };

        xdg.configFile."direnv/direnv.toml".text = ''
          [global]
          hide_env_diff = true
        '';

        xdg.configFile."devenv/ray".source = mkDotfilesSymlink {
          inherit config;
          name = "devenv";
        };
      };
  };
}
