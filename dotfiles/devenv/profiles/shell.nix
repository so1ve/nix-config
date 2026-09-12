{ pkgs, ... }:

{
  packages = with pkgs; [
    bash-language-server
    fish-lsp
    shellcheck
    shfmt
  ];
}
