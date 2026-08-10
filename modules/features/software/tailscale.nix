{
  ray.features."software/tailscale".nixos =
    {
      config,
      username,
      ...
    }:
    {
      services.tailscale = {
        enable = true;
        extraSetFlags = [ "--operator=${username}" ];
      };

      networking.firewall = {
        trustedInterfaces = [ config.services.tailscale.interfaceName ];
        allowedUDPPorts = [ config.services.tailscale.port ];
      };

      systemd.services.tailscaled.serviceConfig.Environment = [
        "TS_DEBUG_FIREWALL_MODE=nftables"
      ];
    };

  ray.features."software/tailscale".home =
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
}
