{
  ray.features = {
    "software/gaming" = {
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

      home = {
        programs.mangohud.enable = true;
      };
    };

    "software/netease-cloud-game" = {
      requires = [ "software/chrome" ];
      nixos = {
        ray.chromeWebApps = [
          {
            url = "https://cg.163.com/";
            custom_name = "网易云游戏";
          }
        ];
      };
    };

    "software/hmcl".home =
      { pkgs, ... }:
      let
        hmclScaled = pkgs.symlinkJoin {
          name = "hmcl-scaled";
          paths = [ pkgs.hmcl ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            # Intentionally kept at 2x scaling instead of 1.75 for better font rendering
            wrapProgram "$out/bin/hmcl" --set GDK_SCALE 2
          '';
        };
      in
      {
        home.packages = [ hmclScaled ];
      };
  };
}
