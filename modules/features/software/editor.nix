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
          programs.neovim = {
            enable = true;
            package = inputs.neovim-nightly-overlay.packages.${system}.default;
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

          xdg.configFile."nvim".source = mkDotfilesSymlink {
            inherit config;
            name = "nvim";
          };
        };
    };

    "defaults/editor/neovim" = {
      requires.allOf = [ "software/neovim" ];
      home = {
        home.sessionVariables = {
          EDITOR = "nvim";
          MANPAGER = "nvim +Man!";
          SUDO_EDITOR = "nvim";
          VISUAL = "nvim";
        };

        programs = {
          git.settings = {
            core.editor = "nvim";
            diff.tool = "nvimdiff";
            merge.tool = "nvimdiff";
          };

          neovim = {
            defaultEditor = true;
            viAlias = true;
            vimAlias = true;
          };
        };
      };
    };

    "software/zed" = {
      home.programs.zed-editor.enable = true;
    };
  };
}
