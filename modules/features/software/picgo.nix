{
  ray.features."software/picgo".home =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.picgo ];
    };
}
