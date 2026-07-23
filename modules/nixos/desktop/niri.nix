{ pkgs, ... }:

{
  programs.niri.enable = true;

  # Niri starts xwayland-satellite automatically when it is on PATH.
  # This supports individual X11-only applications without enabling an
  # X11 desktop session.
  environment.systemPackages = [
    pkgs.xwayland-satellite
  ];
}
