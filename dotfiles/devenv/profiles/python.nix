{ pkgs, ... }:

{
  packages = with pkgs; [
    basedpyright
    python3
    ruff
    tombi
    uv
  ];
}
