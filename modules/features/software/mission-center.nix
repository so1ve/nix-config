{
  ray.features."software/mission-center".home =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.mission-center ];
    };
}
