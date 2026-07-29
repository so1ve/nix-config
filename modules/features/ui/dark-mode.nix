{
  ray.features."ui/dark-mode" = {
    home =
      { pkgs, ... }:
      {
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
  };
}
