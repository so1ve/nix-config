{
  ray.features."desktop/hyprland" = {
    nixos = {
      programs.hyprland.enable = true;
    };

    home =
      {
        config,
        mkDotfilesSymlink,
        ...
      }:
      {
        xdg.configFile."hypr".source = mkDotfilesSymlink {
          inherit config;
          name = "hypr";
        };
      };
  };
}
