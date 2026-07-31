let
  mountPoint = "/mnt/nas";
in
{
  ray.features."storage/mount/nas" = {
    nixos =
      { ... }:
      {
        boot.supportedFilesystems = [ "nfs" ];

        systemd.mounts = [
          {
            description = "NAS NFS share";
            what = "192.168.10.60:/volume4/data";
            where = mountPoint;
            type = "nfs";
            options = "nfsvers=4.1,proto=tcp,hard";
            mountConfig = {
              TimeoutSec = "10s";
              LazyUnmount = true;
              ForceUnmount = true;
            };
          }
        ];

        systemd.automounts = [
          {
            description = "Automount NAS NFS share";
            where = mountPoint;
            wantedBy = [ "remote-fs.target" ];
            before = [ "remote-fs.target" ];
            automountConfig.TimeoutIdleSec = "5min";
          }
        ];
      };

    home =
      {
        mkDolphinPlace,
        ...
      }:
      mkDolphinPlace {
        id = "nix-nas";
        href = "file://${mountPoint}";
        title = "NAS (local)";
        icon = "network-server";
      };
  };
}
