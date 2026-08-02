{
  ray.features."software/winboat" = {
    home =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.nur.repos.so1ve.winboat ];
      };
  };
}
