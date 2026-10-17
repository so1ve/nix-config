{
  ray.features = {
    "software/alger-music-player".home =
      { inputs, pkgs, ... }:
      {
        home.packages = [
          (import inputs.so1ve { inherit pkgs; }).alger-music-player
        ];
      };

    "software/yesplaymusic".home =
      { inputs, pkgs, ... }:
      {
        home.packages = [
          (import inputs.so1ve { inherit pkgs; }).yesplaymusic
        ];
      };

    "software/netease-cloud-music-gtk".home =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.netease-cloud-music-gtk ];
      };
  };
}
