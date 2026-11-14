{
  ray.features."software/yanhekt-autoslides".home =
    _:
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.so1ve.yanhekt-autoslides
      ];
    };
}
