{
  ray.features = {
    "software/wps".home =
      { pkgs, ... }:
      let
        wpsScaled = pkgs.symlinkJoin {
          name = "wpsoffice-scaled";
          paths = [ pkgs.wpsoffice-cn ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            for program in wps et wpp wpspdf; do
              # use QT_FONT_DPI here instead of QT_SCALE_FACTOR because WPS does not respect QT_SCALE_FACTOR
              # QT_FONT_DPI defaults to 96, so we set it to 168 for 1.75x scaling
              wrapProgram "$out/bin/$program" --set QT_FONT_DPI 168
            done
          '';
        };
      in
      {
        home.packages = [ wpsScaled ];
      };

    "software/onlyoffice".home =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.onlyoffice-desktopeditors ];
      };
  };
}
