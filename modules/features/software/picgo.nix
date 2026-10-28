{
  ray.features."software/picgo".home =
    _:
    { pkgs, ... }:
    {
      home.packages = [ pkgs.picgo ];
    };
}
