{ pkgs, ... }:
{
  imports = [
    ./programs/firefox.nix
    ./programs/git.nix
    ./programs/neovim.nix
    ./programs/shells.nix
  ];

  home = {
    username = "ray";
    homeDirectory = "/home/ray";

    stateVersion = "26.05";

    packages = with pkgs; [
      btop
      fd
      gcc
      nodejs
      python3
      ripgrep
      tree-sitter
      unzip
      wget

      unstable.codex
    ];

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      SUDO_EDITOR = "nvim";
    };
  };

  programs.home-manager.enable = true;
}
