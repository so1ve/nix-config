{
  ray.features."software/kde-connect" = {
    nixos = {
      programs.kdeconnect = {
        enable = true;
        package = null;
      };
    };

    home = {
      services.kdeconnect = {
        enable = true;
        indicator = true;
      };

      xdg.mimeApps = {
        enable = true;
        defaultApplications."x-scheme-handler/kdeconnect" = "org.kde.dolphin.desktop";
      };
    };
  };
}
