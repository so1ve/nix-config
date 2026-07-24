{
  ray.features."software/neovim" = {
    home =
      {
        inputs,
        pkgs,
        ...
      }:
      {
        home.packages = [ pkgs.wl-clipboard ];

        programs.neovim = {
          enable = true;
          package = inputs.neovim-nightly-overlay.packages.${pkgs.stdenv.hostPlatform.system}.default;
          defaultEditor = true;
          viAlias = true;
          vimAlias = true;
          sideloadInitLua = true;
        };

        xdg.configFile."nvim".source = ../../../dotfiles/nvim;
      };
  };
}
