{
  ray.features."software/kelivo".home =
    _:
    { pkgs, ... }:
    {
      home.packages = [ pkgs.so1ve.kelivo ];
    };
}
