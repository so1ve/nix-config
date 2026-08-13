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
              "__DEVENV__"
            ]
            [
              moduleRoot
              (lib.getExe pkgs.git)
              (lib.getExe pkgs.devenv)
            ]
            (builtins.readFile ./development/dev-env.js);
        devEnv = pkgs.writers.writeJSBin "dev-env" { } script;
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

          # When a hook-spawned shell leaves project A directly for project B,
          # the parent follows it to B after its activation check has already
          # run. Re-check immediately instead of waiting for the next prompt.
          functions -c _devenv_hook __devenv_hook_once
          functions -e _devenv_hook
          function _devenv_hook --on-event fish_prompt
            set -l previous_pwd $PWD
            __devenv_hook_once
            if test "$PWD" != "$previous_pwd"
              __devenv_hook_once
            end
          end
        '';

        xdg.configFile."devenv/ray".source = mkDotfilesSymlink {
          inherit config;
          name = "devenv";
        };
      };
  };
}
