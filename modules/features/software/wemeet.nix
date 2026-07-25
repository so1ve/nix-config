{
  ray.features."software/wemeet" = {
    home =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.wemeet ];
      };
  };
}
