{
  ray.features."software/relvi" = {
    requires.anyOf = [
      "desktop/hyprland"
      "desktop/niri"
    ];

    home =
      {
        inputs,
        lib,
        pkgs,
        ...
      }:
      let
        package = inputs.relvi.packages.${pkgs.stdenv.hostPlatform.system}.default;
      in
      {
        home.packages = [ package ];

        systemd.user.services.relvi = {
          Unit = {
            Description = "Relvi application launcher";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
          };

          Service = {
            Type = "dbus";
            BusName = "dev.so1ve.Relvi";
            ExecStart = "${lib.getExe package} daemon";
            ExecStop = "${lib.getExe package} quit";
            Restart = "on-failure";
            RestartSec = 3;
            # Applications launched by Relvi must outlive the launcher.
            KillMode = "process";
          };

          Install.WantedBy = [ "graphical-session.target" ];
        };
      };
  };
}
