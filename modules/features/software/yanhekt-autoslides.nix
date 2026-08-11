{
  ray.features."software/yanhekt-autoslides".home =
    { inputs, pkgs, ... }:
    {
      home.packages = [
        inputs.so1ve.packages.${pkgs.stdenv.hostPlatform.system}.yanhekt-autoslides
      ];
    };
}
