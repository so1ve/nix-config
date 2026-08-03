{
  ray.features = {
    "software/codex".home =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.codex ];
      };

    "software/pi".home =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.pi-coding-agent ];
      };
  };
}
