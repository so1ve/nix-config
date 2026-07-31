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

    "software/netease-cloud-game".home =
      {
        config,
        mkChromiumPwa,
        pkgs,
        ...
      }:
      mkChromiumPwa {
        inherit config pkgs;
        name = "netease-cloud-game";
        desktopName = "网易云游戏";
        description = "网易官方云游戏平台";
        categories = [ "Game" ];
        url = "https://cg.163.com/";
        icon = pkgs.fetchurl {
          url = "https://cg.163.com/logo2.png";
          hash = "sha256-bK/ZWd44q1MD+ldoem4So0TyctRqnl5JFT/eGOUF9oM=";
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
            wrapProgram "$out/bin/hmcl" --set GDK_SCALE 2
          '';
        };
      in
      {
        home.packages = [ hmclScaled ];
      };
  };
}
