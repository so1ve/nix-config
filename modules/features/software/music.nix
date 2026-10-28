{
  ray.features = {
    "software/go-musicfox".home =
      _:
      { pkgs, ... }:
      {
        home.packages = [ pkgs.go-musicfox ];
      };

    "software/alger-music-player".home =
      _:
      { inputs, pkgs, ... }:
      {
        home.packages = [
          (import inputs.so1ve { inherit pkgs; }).alger-music-player
        ];
      };

    "software/yesplaymusic".home =
      _:
      { inputs, pkgs, ... }:
      {
        home.packages = [
          (import inputs.so1ve { inherit pkgs; }).yesplaymusic
        ];
      };

    "software/netease-cloud-music-gtk".home =
      _:
      { pkgs, ... }:
      {
        home.packages = [ pkgs.netease-cloud-music-gtk ];
      };
  };
}
