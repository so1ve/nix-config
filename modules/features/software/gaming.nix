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
        mkFirefoxPwaInstall,
        pkgs,
        ...
      }:
      mkFirefoxPwaInstall {
        inherit config pkgs;
        name = "netease-cloud-game";
        description = "Install NetEase Cloud Game as a Firefox PWA";
        manifestUrl = "https://cg.163.com/manifestindex.json";
        installArgs = [
          "--document-url"
          "https://cg.163.com/"
          "--start-url"
          "https://cg.163.com/"
          "--icon-url"
          "https://cg.163.com/logo2.png"
          "--name"
          "网易云游戏"
          "--description"
          "网易官方云游戏平台"
        ];
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
