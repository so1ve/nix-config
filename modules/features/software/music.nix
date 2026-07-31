{
  ray.features = {
    "software/alger-music-player".home =
      {
        lib,
        mkAppImage,
        pkgs,
        ...
      }:
      {
        home.packages = [
          (mkAppImage {
            inherit pkgs;
            pname = "alger-music-player";
            version = "5.1.0";
            url = "https://github.com/algerkong/AlgerMusicPlayer/releases/download/v5.1.0/AlgerMusicPlayer-5.1.0-linux-x86_64.AppImage";
            hash = "sha256-nYMDNSpyyCHRKIBhP++sA7FmodSHBUwRSPEM8yLFaF0=";
            desktopFile = "algermusicplayer.desktop";
            iconPath = "usr/share/icons/hicolor/1084x1084/apps/algermusicplayer.png";
            description = "Third-party NetEase Cloud Music player";
            homepage = "https://github.com/algerkong/AlgerMusicPlayer";
            license = lib.licenses.mit;
          })
        ];
      };

    "software/yesplaymusic".home =
      {
        lib,
        mkAppImage,
        pkgs,
        ...
      }:
      {
        home.packages = [
          (mkAppImage {
            inherit pkgs;
            pname = "yesplaymusic";
            version = "0.4.10";
            url = "https://github.com/qier222/YesPlayMusic/releases/download/v0.4.10/YesPlayMusic-0.4.10.AppImage";
            hash = "sha256-Qj9ZQbHqzKX2QBlXWtey/j/4PqrCJCObdvOans79KW4=";
            desktopFile = "yesplaymusic.desktop";
            iconPath = "usr/share/icons/hicolor/512x512/apps/yesplaymusic.png";
            description = "Third-party NetEase Cloud Music player";
            homepage = "https://github.com/qier222/YesPlayMusic";
            license = lib.licenses.mit;
          })
        ];
      };

    "software/netease-cloud-music-gtk".home =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.netease-cloud-music-gtk ];
      };
  };
}
