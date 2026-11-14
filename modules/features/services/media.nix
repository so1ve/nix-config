{ lib, ... }:

{
  ray.features."services/media" = {
    requires.allOf = [ "virtualisation/podman" ];

    options = {
      uid = lib.mkOption {
        type = lib.types.ints.unsigned;
        description = "Media user ID, matching ownership on the host's media storage.";
      };

      gid = lib.mkOption {
        type = lib.types.ints.unsigned;
        description = "Media group ID, matching ownership on the host's media storage.";
      };
    };

    nixos = { settings, ... }: {
      users = {
        groups.media.gid = settings.gid;
        users.media = {
          isSystemUser = true;
          uid = settings.uid;
          group = "media";
        };
      };

      networking.firewall.interfaces.br-media = {
        allowedTCPPorts = [ 53 ];
        allowedUDPPorts = [ 53 ];
      };

      virtualisation.quadlet.networks.media.networkConfig = {
        NetworkName = "media";
        InterfaceName = "br-media";
        IPv6 = true;
      };
    };
  };
}
