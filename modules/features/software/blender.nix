{
  ray.features."software/blender".home =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.blender ];
    };
}
