{ pkgs, ... }:

{
  packages = with pkgs; [
    python3
    uv
  ];
}
