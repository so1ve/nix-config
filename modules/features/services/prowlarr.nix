{
  ray.features."services/prowlarr" = {
    requires.allOf = [ "virtualisation/podman" ];

    nixos = _: { config, ... }: {
      virtualisation.quadlet = {
        volumes.prowlarr = { };

        containers.prowlarr.containerConfig = {
          Image = "docker.io/linuxserver/prowlarr@sha256:431d7efebcef466e56adaa40a7a2fa2b0e85159a037b8bf465eaadbf0cf5bedf";
          Network = [ config.virtualisation.quadlet.networks.media.ref ];
          NetworkAlias = [ "prowlarr" ];
          PublishPort = [ "9696:9696" ];
          Volume = [ "${config.virtualisation.quadlet.volumes.prowlarr.ref}:/config" ];
          Environment = {
            PUID = toString config.users.users.media.uid;
            PGID = toString config.users.groups.media.gid;
            TZ = config.time.timeZone;
          };
        };
      };
    };
  };
}
