{
  ray.features = {
    "software/wps".home =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.wpsoffice-cn ];
      };

    "software/onlyoffice".home =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.onlyoffice-desktopeditors ];
      };
  };
}
