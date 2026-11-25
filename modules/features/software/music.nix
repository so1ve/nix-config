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
      { pkgs, ... }:
      {
        home.packages = [ pkgs.so1ve.alger-music-player ];
      };

    "software/yesplaymusic".home =
      _:
      { pkgs, ... }:
      {
        home.packages = [
          (pkgs.so1ve.yesplaymusic.withPlugins (
            p: with p; [
              netease
              qqmusic
            ]
          ))
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
