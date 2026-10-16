{
  ray.features = {
    "software/alger-music-player".home =
      { inputs, pkgs, ... }:
      {
        home.packages = [
          inputs.so1ve.packages.${pkgs.stdenv.hostPlatform.system}.alger-music-player
        ];
      };

    "software/yesplaymusic".home =
      { inputs, pkgs, ... }:
      {
        home.packages = [
          inputs.so1ve.packages.${pkgs.stdenv.hostPlatform.system}.yesplaymusic
        ];
      };

    "software/netease-cloud-music-gtk".home =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.netease-cloud-music-gtk ];
      };
  };
}
