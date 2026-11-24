{
  ray.features."software/development" = {
    nixos =
      _:
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
      _:
      {
        config,
        inputs,
        lib,
        mkDotfilesSource,
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
          pkgs.so1ve.cargo-pretty
          devEnv
          pkgs.devenv
          pkgs.ni
        ];

        home.shellAliases = {
          cb = "cargo pretty build";
          cr = "cargo pretty run";
          ct = "cargo pretty test";
        };

        programs.direnv-instant = {
          enable = true;
          settings.mux_delay = 30;
        };

        xdg.configFile = {
          "direnv/direnv.toml".text = ''
            [global]
            hide_env_diff = true
          '';

          "devenv/ray".source = mkDotfilesSource "devenv";

          "fish/completions/nr.fish" = {
            enable = config.home.shell.enableFishIntegration;
            text = ''
              function _nr_completion
                set -l tokens (commandline -xpc)
                if test (count $tokens) -ge 1
                  set tokens $tokens[2..-1]
                end
                ${lib.getExe' pkgs.ni "nr"} --completion --programmatic $tokens 2>/dev/null
              end

              complete -c nr -f
              complete -c nr -n 'test -f package.json' -a '(_nr_completion)' -d 'package.json scripts'
            '';
          };
        };
      };
  };
}
