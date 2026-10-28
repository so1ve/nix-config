{ lib, ... }:
{
  ray.features."software/tailscale" = {
    options = {
      acceptRoutes = lib.mkEnableOption "routes advertised by other Tailscale nodes";
      ssh = lib.mkEnableOption "Tailscale SSH";
    };

    nixos =
      settings:
      {
        config,
        username,
        ...
      }:
      {
        services.tailscale = {
          enable = true;
          extraSetFlags = [
            "--operator=${username}"
            "--accept-routes=${lib.boolToString settings.acceptRoutes}"
            "--ssh=${lib.boolToString settings.ssh}"
          ];
        };

        networking.firewall = {
          trustedInterfaces = [ config.services.tailscale.interfaceName ];
          allowedUDPPorts = [ config.services.tailscale.port ];
        };

        systemd.services.tailscaled.environment.TS_DEBUG_FIREWALL_MODE = "nftables";
      };
  };

  ray.features."software/tailscale/systray" = {
    requires.allOf = [ "software/tailscale" ];

    home =
      _:
      { pkgs, ... }:
      {
        systemd.user.services.tailscale-systray = {
          Unit = {
            Description = "Tailscale system tray";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
          };

          Service = {
            ExecStart = "${pkgs.tailscale}/bin/tailscale systray";
            Restart = "on-failure";
            RestartSec = 3;
          };

          Install.WantedBy = [ "graphical-session.target" ];
        };
      };
  };
}
