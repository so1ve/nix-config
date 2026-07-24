{
  ray.features."software/qq" = {
    home =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.qq ];
      };
  };
}
