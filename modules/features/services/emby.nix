{ images, lib, ... }:

{
  ray.features."services/emby" = {
    requires.allOf = [
      "virtualisation/podman"
      "services/traefik"
    ];

    options = {
      domain = lib.mkOption { type = lib.types.str; };

      mediaRoot = lib.mkOption {
        type = lib.types.str;
        description = "Host media directory mounted at /video.";
      };

      lanInterface = lib.mkOption {
        type = lib.types.str;
        description = "Host interface used for LAN access and discovery.";
      };

      lanSubnet = lib.mkOption {
        type = lib.types.str;
        description = "IPv4 subnet allowed to access and discover Emby directly.";
      };
    };

    nixos = { settings, ... }: { config, ... }: {
      networking.firewall = {
        interfaces = {
          br-media.allowedTCPPorts = [ 8096 ];
          br-traefik.allowedTCPPorts = [ 8096 ];
          ${config.services.tailscale.interfaceName}.allowedTCPPorts =
            lib.mkIf config.services.tailscale.enable
              [ 8096 ];
        };
        # for lan discovery
        extraInputRules = ''
          iifname "${settings.lanInterface}" ip saddr ${settings.lanSubnet} tcp dport 8096 accept
          iifname "${settings.lanInterface}" ip saddr ${settings.lanSubnet} udp dport { 1900, 7359 } accept
        '';
      };

      virtualisation.quadlet = {
        volumes.emby = { };

        containers.emby.containerConfig = {
          Image = images.emby;
          Network = [ "host" ];
          AddDevice = [ "/dev/dri" ];
          Volume = [
            "${config.virtualisation.quadlet.volumes.emby.ref}:/config"
            "${settings.mediaRoot}:/video"
          ];
          Environment = {
            UID = toString config.users.users.media.uid;
            GID = toString config.users.groups.media.gid;
            GIDLIST = lib.concatMapStringsSep "," toString [
              config.users.groups.render.gid
              config.users.groups.video.gid
            ];
            TZ = config.time.timeZone;
          };
          Label = {
            "traefik.enable" = "true";
            "traefik.http.routers.emby.rule" = "Host(`${settings.domain}`)";
            "traefik.http.services.emby.loadbalancer.server.port" = "8096";
          };
        };
      };
    };
  };
}
