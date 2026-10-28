{
  ray.features."software/blender".home =
    _:
    { pkgs, ... }:
    {
      home.packages = [ pkgs.blender ];
    };
}
