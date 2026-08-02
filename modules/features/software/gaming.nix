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
        mkIcon,
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
        icon = mkIcon "netease-cloud-game.png";
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
