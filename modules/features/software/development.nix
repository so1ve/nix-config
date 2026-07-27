{
  ray.features."software/development" = {
    home =
      {
        config,
        lib,
        mkDotfilesSymlink,
        pkgs,
        ...
      }:
      let
        moduleRoot = "${config.xdg.configHome}/devenv/ray";
        devEnv = pkgs.writeShellApplication {
          name = "dev-env";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.devenv
            pkgs.git
            pkgs.gnugrep
            pkgs.nixfmt
          ];
          text = ''
            if [[ -z "''${RAY_DEVENV_MODULE_ROOT:-}" ]]; then
              export RAY_DEVENV_MODULE_ROOT=${lib.escapeShellArg moduleRoot}
            fi
            ${builtins.readFile ./development/dev-env.sh}
          '';
        };
      in
      {
        home.packages = [
          devEnv
          pkgs.devenv
        ];

        programs.bash.initExtra = lib.mkAfter ''
          eval "$(${pkgs.devenv}/bin/devenv hook bash)"
        '';

        programs.fish.interactiveShellInit = lib.mkAfter ''
          ${pkgs.devenv}/bin/devenv hook fish | source
        '';

        xdg.configFile."devenv/ray".source = mkDotfilesSymlink {
          inherit config;
          name = "devenv";
        };
      };
  };
}
