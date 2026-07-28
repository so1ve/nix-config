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
            copilot-language-server
            curl
            gnutar
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
}
