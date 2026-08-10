let
  mountPoint = "/mnt/nas";
in
{
  ray.features."storage/mount/nas" = {
    nixos =
      { ... }:
      {
        fileSystems.${mountPoint} = {
          device = "192.168.10.60:/volume4/data";
          fsType = "nfs";
          options = [
            "_netdev"
            "nfsvers=4.1"
            "proto=tcp"
            "hard"
            "x-systemd.automount"
            "x-systemd.idle-timeout=5min"
            "x-systemd.mount-timeout=10s"
            # Keep NFS available until every user process has exited.
            "x-systemd.before=user.slice"
          ];
        };
      };

    # Accessing the bookmark triggers the systemd automount without asking GVfs
    # to run mount(8) as the desktop user.
    home =
      { ... }:
      {
        xdg.configFile."gtk-3.0/bookmarks".text = "file://${mountPoint} NAS (local)\n";
      };
  };
}
