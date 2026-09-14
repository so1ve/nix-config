{
  ray.features."software/kelivo".home =
    { inputs, pkgs, ... }:
    {
      home.packages = [
        inputs.so1ve.packages.${pkgs.stdenv.hostPlatform.system}.kelivo
      ];
    };
}
