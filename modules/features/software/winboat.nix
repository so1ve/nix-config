{
  ray.features."software/winboat" = {
    home =
      { inputs, pkgs, ... }:
      {
        home.packages = [ inputs.so1ve.packages.${pkgs.stdenv.hostPlatform.system}.winboat ];
      };
  };
}
