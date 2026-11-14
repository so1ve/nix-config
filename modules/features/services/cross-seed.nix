{ images, ... }:

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
          Image = images.cross-seed;
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
