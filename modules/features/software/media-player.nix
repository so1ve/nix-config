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
