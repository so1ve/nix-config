{
  ray.features = {
    "software/mpv".home =
      _:
      {
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

          bindings = {
            LEFT = "seek -5 exact";
            RIGHT = "seek 5 exact";
            UP = "add volume 5";
            DOWN = "add volume -5";
          };

          config = {
            hwdec = "auto-safe";
            osc = false;
            osd-bar = false;
            save-position-on-quit = true;
          };
        };
      };

    "software/haruna".home =
      _:
      { pkgs, ... }:
      {
        home.packages = [ pkgs.haruna ];
      };

    "software/celluloid".home =
      _:
      { pkgs, ... }:
      {
        home.packages = [ pkgs.celluloid ];
      };

    "software/vlc".home =
      _:
      { pkgs, ... }:
      {
        home.packages = [ pkgs.vlc ];
      };
  };
}
