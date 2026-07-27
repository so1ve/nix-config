{ pkgs, ... }:

{
  packages = with pkgs; [
    shellcheck
    shfmt
  ];
}
