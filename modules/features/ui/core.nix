{
  ray.features."ui/core".home =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.qt6.qtsvg ];

      gtk = {
        enable = true;
        colorScheme = "dark";
        iconTheme = {
          name = "Papirus-Dark";
          package = pkgs.papirus-icon-theme;
        };
      };

      qt = {
        enable = true;
        platformTheme.name = "xdgdesktopportal";
        style.name = "adwaita-dark";
      };
    };
}
