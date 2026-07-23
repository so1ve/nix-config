{ ... }:
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    sideloadInitLua = true;
  };

  xdg.configFile."nvim".source = ../../../dotfiles/nvim;
}
