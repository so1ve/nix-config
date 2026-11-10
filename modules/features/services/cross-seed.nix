{
  ray.features."services/cross-seed" = {
    requires.allOf = [ "virtualisation/podman" ];

    nixos = _: { config, ... }: {
      virtualisation.quadlet = {
        volumes.cross-seed.volumeConfig = {
          User = config.users.users.media.uid;
          Group = config.users.groups.media.gid;
        };

        containers.cross-seed.containerConfig = {
          Image = "ghcr.io/cross-seed/cross-seed@sha256:9279fa3b4c6f09915614ec819c6dc97e1e844d863b35c009ababd54bad0489d5";
          User = "${toString config.users.users.media.uid}:${toString config.users.groups.media.gid}";
          Network = [ config.virtualisation.quadlet.networks.media.ref ];
          NetworkAlias = [ "cross-seed" ];
          PublishPort = [ "2468:2468" ];
          Volume = [ "${config.virtualisation.quadlet.volumes.cross-seed.ref}:/config" ];
          Exec = "daemon";
        };
      };
    };
  };
}
