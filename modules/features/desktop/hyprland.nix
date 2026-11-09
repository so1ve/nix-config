{
  ray.features."desktop/hyprland" = {
    nixos = _: {
      programs.hyprland = {
        enable = true;
        withUWSM = true;
      };
    };

    home =
      _:
      { mkDotfilesSource, ... }:
      {
        xdg.configFile."hypr".source = mkDotfilesSource "hypr";
      };
  };
}
