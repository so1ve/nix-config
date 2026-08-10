{
  ray.features."ui/core".home =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.qt6.qtsvg ];

      home.pointerCursor = {
        enable = true;
        gtk.enable = true;
        name = "phinger-cursors-light";
        package = pkgs.phinger-cursors;
        size = 24;
      };

      gtk = {
        enable = true;
        colorScheme = "dark";
        iconTheme = {
          name = "Tela-dark";
          package = pkgs.tela-icon-theme;
        };
      };

      qt = {
        enable = true;
        platformTheme.name = "xdgdesktopportal";
        style.name = "adwaita-dark";
      };
    };
}
