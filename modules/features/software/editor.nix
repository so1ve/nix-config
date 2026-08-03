{
  ray.features = {
    "software/neovim" = {
      home =
        {
          config,
          inputs,
          mkDotfilesSymlink,
          pkgs,
          system,
          ...
        }:
        {
          home.sessionVariables = {
            EDITOR = "nvim";
            VISUAL = "nvim";
            SUDO_EDITOR = "nvim";
          };

          programs = {
            git.settings = {
              core.editor = "nvim";
              diff.tool = "nvimdiff";
              merge.tool = "nvimdiff";
            };

            neovim = {
              enable = true;
              package = inputs.neovim-nightly-overlay.packages.${system}.default;
              defaultEditor = true;
              viAlias = true;
              vimAlias = true;
              sideloadInitLua = true;
              extraPackages = with pkgs; [
                bash-language-server
                copilot-language-server
                curl
                fish-lsp
                gnutar
                shellcheck
                shfmt
                stdenv.cc
                tree-sitter
              ];
            };
          };

          xdg.configFile."nvim".source = mkDotfilesSymlink {
            inherit config;
            name = "nvim";
          };
        };
    };

    "software/zed" = {
      home.programs.zed-editor.enable = true;
    };
  };
}
