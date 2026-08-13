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

          # The hook spawns `devenv shell` in the foreground and blocks the
          # outer fish until its nested fish exits. The spawn is triggered by
          # a fish_prompt event, so no fish_preexec fires and @pane-is-fish
          # stays 1 while `devenv shell` evaluates; tmux keeps passing
          # C-h/C-j/C-k/C-l through to the pane, where the spawn swallows
          # them. Mark the pane busy around the spawn and restore it when the
          # hook returns, so tmux navigates directly instead.
          functions -c _devenv_hook_activate __devenv_hook_activate
          function _devenv_hook_activate --argument-names project_dir
            functions -q __fish_set_tmux_pane_state; and __fish_set_tmux_pane_state 0
            __devenv_hook_activate $project_dir
            functions -q __fish_set_tmux_pane_state; and __fish_set_tmux_pane_state 1
          end
        '';

        xdg.configFile."devenv/ray".source = mkDotfilesSymlink {
          inherit config;
          name = "devenv";
        };
      };
  };
}
