{
  ray.features."software/mission-center".home =
    _:
    { pkgs, ... }:
    {
      home.packages = [ pkgs.mission-center ];
    };
}
