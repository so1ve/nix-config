{
  ray.features."ui/core".home =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.kdePackages.kio
        pkgs.qt6.qtsvg
      ];

      gtk = {
        enable = true;
        colorScheme = "dark";
      };

      qt = {
        enable = true;
        platformTheme = {
          name = "kde";
          package = pkgs.kdePackages.plasma-integration;
        };
        style.name = "breeze";
      };

      xdg.configFile."kdeglobals".source =
        "${pkgs.kdePackages.breeze}/share/color-schemes/BreezeDark.colors";
    };
}
