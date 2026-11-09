{ lib, ... }:
{
  ray.features."services/cross-seed" = {
    requires.allOf = [ "virtualisation/podman" ];
    options.dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/cross-seed";
    };
    nixos = { settings, ... }: { config, ... }: {
      systemd.tmpfiles.rules = [ "d ${settings.dataDir} 0750 media media - -" ];
      virtualisation.quadlet.containers.cross-seed.containerConfig = {
        Image = "ghcr.io/cross-seed/cross-seed@sha256:9279fa3b4c6f09915614ec819c6dc97e1e844d863b35c009ababd54bad0489d5";
        User = "${toString config.users.users.media.uid}:${toString config.users.groups.media.gid}";
        Network = [ config.virtualisation.quadlet.networks.media.ref ];
        NetworkAlias = [ "cross-seed" ];
        Volume = [ "${settings.dataDir}:/config" ];
        Exec = "daemon";
      };
    };
  };
}
