{
  ray.features."software/wine" = {
    home =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.wineWow64Packages.waylandFull
          pkgs.winetricks
          (pkgs.bottles.override {
            removeWarningPopup = true;
          })
        ];
      };
  };
}
