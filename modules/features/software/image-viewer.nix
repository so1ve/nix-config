{
  ray.features = {
    "software/swayimg".home =
      _:
      { pkgs, ... }:
      {
        home.packages = [ pkgs.swayimg ];
      };

    "software/gwenview".home =
      _:
      { pkgs, ... }:
      {
        home.packages = [ pkgs.kdePackages.gwenview ];
      };
  };
}
