{
  ray.features = {
    "software/mpv".home =
      {
        lib,
        pkgs,
        ...
      }:
      {
        programs.mpv = {
          enable = true;

          scripts = with pkgs.mpvScripts; [
            mpris
            thumbfast
            uosc
          ];

          scriptOpts.uosc.languages = "zh-hans,slang,en";

          config = {
            hwdec = "auto-safe";
            osc = false;
            osd-bar = false;
            save-position-on-quit = true;
          };
        };

        xdg.mimeApps = {
          enable = true;
          defaultApplications = lib.genAttrs [
            "application/ogg"
            "application/vnd.apple.mpegurl"
            "audio/aac"
            "audio/flac"
            "audio/mp4"
            "audio/mpeg"
            "audio/ogg"
            "audio/opus"
            "audio/x-matroska"
            "audio/x-mpegurl"
            "audio/x-wav"
            "video/3gpp"
            "video/3gpp2"
            "video/mp2t"
            "video/mp4"
            "video/mpeg"
            "video/ogg"
            "video/quicktime"
            "video/webm"
            "video/x-flv"
            "video/x-matroska"
            "video/x-msvideo"
          ] (_: "mpv.desktop");
        };
      };

    "software/haruna".home =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.haruna ];
      };

    "software/celluloid".home =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.celluloid ];
      };

    "software/vlc".home =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.vlc ];
      };
  };
}
