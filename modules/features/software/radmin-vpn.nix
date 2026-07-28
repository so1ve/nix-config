{
  ray.features."software/radmin-vpn" = {
    home =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.nur.repos.so1ve.radmin-vpn ];
      };
  };
}
