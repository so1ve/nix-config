{
  ray.features."software/dolphin" = {
    nixos = {
      services.udisks2.enable = true;
    };

    home =
      { pkgs, ... }:
      {
        home.packages = with pkgs.kdePackages; [
          ark
          breeze-icons
          dolphin
          ffmpegthumbs
          kdegraphics-thumbnailers
          kio-admin
          kio-extras
        ];

        xdg.mimeApps = {
          enable = true;
          defaultApplications."inode/directory" = "org.kde.dolphin.desktop";
        };
      };
  };
}
