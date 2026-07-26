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
            clang-tools
            docker-compose-language-service
            dockerfile-language-server
            fish
            fish-lsp
            gofumpt
            gopls
            gotools
            lua-language-server
            nixd
            nixfmt
            prettier
            prettierd
            ruff
            stylua
            texlab
            texlivePackages.latexindent
            tinymist
            tombi
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
