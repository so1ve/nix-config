{
  ray.features."software/neovim" = {
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
          defaultEditor = true;
          viAlias = true;
          vimAlias = true;
          sideloadInitLua = true;
          extraPackages = with pkgs; [
            basedpyright
            bash-language-server
            clang-tools
            docker-compose-language-service
            dockerfile-language-server
            fish-lsp
            gofumpt
            gopls
            gotools
            lua-language-server
            nixd
            nixfmt
            nodejs
            python3
            prettier
            prettierd
            ruff
            rust-analyzer
            stylua
            texlab
            texlivePackages.latexindent
            tinymist
            tombi
            tree-sitter
            vscode-langservers-extracted
            vtsls
            vue-language-server
            yaml-language-server
            zls
          ];
        };

        home.sessionVariables = {
          NVIM_VUE_TYPESCRIPT_PLUGIN_PATH = "${pkgs.vue-language-server}/lib/language-tools/packages/language-server";
        };

        xdg.configFile."nvim".source = mkDotfilesSymlink {
          inherit config;
          name = "nvim";
        };
      };
  };
}
