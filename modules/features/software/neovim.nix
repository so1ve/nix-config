{
  ray.features."software/neovim" = {
    home =
      {
        inputs,
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
        };

        xdg.configFile."nvim".source = ../../../dotfiles/nvim;
      };
  };
}
