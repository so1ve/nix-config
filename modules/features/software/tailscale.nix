{ lib, ... }:
{
  ray.features."software/tailscale" = {
    options = {
      acceptRoutes = lib.mkEnableOption "routes advertised by other Tailscale nodes";
      advertiseRoutes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Subnets advertised by this Tailscale node.";
      };
      ssh = lib.mkEnableOption "Tailscale SSH";
      trustInterface = lib.mkEnableOption "unrestricted incoming traffic on the Tailscale interface";
    };

    nixos =
      { settings, ... }:
      {
        config,
        username,
        ...
      }:
      {
        services.tailscale = {
          enable = true;
          useRoutingFeatures = lib.mkIf (settings.advertiseRoutes != [ ]) "server";
          extraSetFlags = [
            "--operator=${username}"
            "--accept-routes=${lib.boolToString settings.acceptRoutes}"
            "--advertise-routes=${lib.concatStringsSep "," settings.advertiseRoutes}"
            "--ssh=${lib.boolToString settings.ssh}"
          ];
        };

        networking.firewall = {
          trustedInterfaces = lib.optional settings.trustInterface config.services.tailscale.interfaceName;
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
