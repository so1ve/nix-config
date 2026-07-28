{ pkgs, ... }:

{
  packages = with pkgs; [
    prettier
    prettierd
    tombi
    vscode-langservers-extracted
    yaml-language-server
  ];
}
