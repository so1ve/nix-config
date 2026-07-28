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
        devEnv = pkgs.writers.writePython3Bin "dev-env" {
          flakeIgnore = [ "E501" ];
          makeWrapperArgs = [
            "--set-default"
            "RAY_DEVENV_MODULE_ROOT"
            moduleRoot
            "--prefix"
            "PATH"
            ":"
            (lib.makeBinPath [
              pkgs.devenv
              pkgs.git
            ])
          ];
        } (builtins.readFile ./development/dev_env.py);
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
          # A shell spawned by the PWD hook can inherit zoxide's temporary
          # recursion guard while zoxide is still changing directories.
          set -e __zoxide_loop
          ${pkgs.devenv}/bin/devenv hook fish | source
        '';

        xdg.configFile."devenv/ray".source = mkDotfilesSymlink {
          inherit config;
          name = "devenv";
        };
      };
  };
}
