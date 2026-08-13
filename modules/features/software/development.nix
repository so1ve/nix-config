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

          # The hook can block inside `devenv shell` until its nested fish
          # exits. Restore the outer fish's pane state after it returns.
          function __fish_tmux_post_devenv_prompt --on-event fish_prompt
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
