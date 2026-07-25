{
  ray.features."software/gaming" = {
    nixos =
      { pkgs, ... }:
      {
        programs = {
          gamemode.enable = true;
          gamescope.enable = true;

          steam = {
            enable = true;
            extraCompatPackages = [ pkgs.proton-ge-bin ];
          };
        };
      };

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

        programs.mangohud.enable = true;
      };
  };
}
