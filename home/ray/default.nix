{ pkgs, ... }:
{
  imports = [
    ./programs/neovim.nix
  ];

  home = {
    username = "ray";
    homeDirectory = "/home/ray";

    stateVersion = "26.05";

    packages = with pkgs; [
      kdePackages.kate

      ripgrep
      fd
      btop
    ];

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      SUDO_EDITOR = "nvim";
    };
  };

  programs.home-manager.enable = true;
}
