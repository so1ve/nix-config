{
  ray.features."software/hmcl" = {
    home =
      { pkgs, ... }:
      let
        hmclScaled = pkgs.symlinkJoin {
          name = "hmcl-scaled";
          paths = [ pkgs.hmcl ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram "$out/bin/hmcl" --set GDK_SCALE 2
          '';
        };
      in
      {
        home.packages = [ hmclScaled ];
      };
  };
}
