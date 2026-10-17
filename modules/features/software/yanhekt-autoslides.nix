{
  ray.features."software/yanhekt-autoslides".home =
    { inputs, pkgs, ... }:
    {
      home.packages = [
        # FIXME: Keep the original nixpkgs pin until the Electron 41 dependency is updated.
        inputs.so1ve.packages.${pkgs.stdenv.hostPlatform.system}.yanhekt-autoslides
      ];
    };
}
