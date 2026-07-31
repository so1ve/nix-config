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
            # Keep NFS available until every user process has exited.  The
            # reverse shutdown order is user.slice -> mount -> automount.
            before = [ "user.slice" ];
            options = "nfsvers=4.1,proto=tcp,hard";
            mountConfig.TimeoutSec = "10s";
          }
        ];

        systemd.automounts = [
          {
            description = "Automount NAS NFS share";
            where = mountPoint;
            wantedBy = [ "remote-fs.target" ];
            before = [
              "remote-fs.target"
              "user.slice"
            ];
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
