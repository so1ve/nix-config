{
  ray.features."desktop/hyprland" = {
    nixos = _: {
      programs.hyprland.enable = true;
    };

    home =
      _:
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
