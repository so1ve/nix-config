{
  ray.features."software/development" = {
    home =
      {
        config,
        dotfilesRoot,
        lib,
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
              "__DEVENV__"
              "__NIXFMT__"
              "__PRETTIER__"
            ]
            [
              moduleRoot
              (lib.getExe pkgs.git)
              (lib.getExe pkgs.devenv)
              (lib.getExe pkgs.nixfmt)
              (lib.getExe pkgs.prettier)
            ]
            (builtins.readFile ./development/dev_env.py);
        devEnv = pkgs.writers.writePython3Bin "dev-env" {
          flakeIgnore = [ "E501" ];
        } script;
      in
      {
        home.packages = [
          devEnv
          pkgs.devenv
          pkgs.ni
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

        xdg.configFile."devenv/ray".source = dotfilesRoot + "/devenv";
      };
  };
}
