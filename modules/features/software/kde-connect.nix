let
  phone = "ad448fa3108d4a268f16bdf9cd1132d6";
in
{
  ray.features."software/kde-connect" = {
    requires = [ "software/dolphin" ];

    nixos = {
      programs.kdeconnect = {
        enable = true;
        package = null;
      };
    };

    home =
      { pkgs, ... }:
      let
        commands = builtins.toJSON {
          presenter-exit = {
            command = "${pkgs.xdotool}/bin/xdotool key Escape";
            name = "Presentation: Exit";
          };
          presenter-next = {
            command = "${pkgs.xdotool}/bin/xdotool key Next";
            name = "Presentation: Next";
          };
          presenter-previous = {
            command = "${pkgs.xdotool}/bin/xdotool key Prior";
            name = "Presentation: Previous";
          };
          presenter-start = {
            command = "${pkgs.xdotool}/bin/xdotool key F5";
            name = "Presentation: Start";
          };
        };
      in
      {
        home.packages = [ pkgs.xdotool ];

        services.kdeconnect = {
          enable = true;
          indicator = true;
        };

        xdg.configFile."kdeconnect/${phone}/kdeconnect_runcommand/config".text = ''
          [General]
          commands="@ByteArray(${builtins.replaceStrings [ "\"" ] [ "\\\"" ] commands})"
        '';

        xdg.mimeApps = {
          enable = true;
          defaultApplications."x-scheme-handler/kdeconnect" = "org.kde.dolphin.desktop";
        };
      };
  };
}
