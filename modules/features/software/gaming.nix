{
  ray.features = {
    "software/gaming" = {
      nixos =
        _:
        { pkgs, ... }:
        {
          boot.kernelModules = [ "ntsync" ];

          environment.systemPackages = with pkgs; [
            lsfg-vk
            lsfg-vk-ui
          ];

          hardware.graphics.extraPackages = [ pkgs.lsfg-vk ];

          programs = {
            gamemode.enable = true;
            gamescope.enable = true;

            steam = {
              enable = true;
              extraPackages = [ pkgs.lsfg-vk ];
              extraCompatPackages = with pkgs; [
                dwproton-bin
                proton-ge-bin
              ];
            };
          };
        };

      home = _: {
        programs.mangohud.enable = true;
      };
    };

    "software/netease-cloud-game" = {
      requires.allOf = [ "software/chrome" ];
      nixos = _: {
        ray.chromeWebApps = [
          {
            url = "https://cg.163.com/";
            custom_name = "网易云游戏";
            appId = "jfmfhdlohbopnadjpiopnfkncjkjaihl";
          }
        ];
      };
    };

    "software/endfield-cloud-game" = {
      requires.allOf = [ "software/chrome" ];
      nixos = _: {
        ray.chromeWebApps = [
          {
            url = "https://endfield.hypergryph.com/cloud";
            custom_name = "云·终末地";
            appId = "jgjehckfkoefhaehfbpjfpeggilbkije";
          }
        ];
      };
    };

    "software/hmcl".home =
      _:
      { pkgs, ... }:
      let
        hmclScaled = pkgs.symlinkJoin {
          name = "hmcl-scaled";
          paths = [ pkgs.so1ve.hmcl ];
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
