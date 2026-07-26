{
  ray.features."software/codex" = {
    home =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.codex ];
      };
  };
}
