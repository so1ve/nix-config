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
            "nfsvers=4.1"
            "proto=tcp"
            "_netdev"
            "nofail"
            "noauto"
            "x-systemd.automount"
            "x-systemd.mount-timeout=10s"
          ];
        };

        # NFS must be detached while the network is still available.  The
        # reverse shutdown ordering of this dependency stops the mount before
        # NetworkManager tears down Wi-Fi.
        systemd.services.NetworkManager.before = [ "mnt-nas.mount" ];
      };

    home =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        place = pkgs.writeText "dolphin-nas-place.xbel" ''
          <bookmark href="file://${mountPoint}">
           <title>NAS (local)</title>
           <info>
            <metadata owner="http://freedesktop.org">
             <bookmark:icon name="network-server"/>
            </metadata>
            <metadata owner="http://www.kde.org">
             <ID>nix-nas</ID>
            </metadata>
           </info>
          </bookmark>
        '';
      in
      {
        home.activation.pinNasInDolphin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          places="${config.home.homeDirectory}/.local/share/user-places.xbel"
          href="file://${mountPoint}"

          if [ -f "$places" ] && ! ${pkgs.gnugrep}/bin/grep -Fq "$href" "$places"; then
            temporary="$(${pkgs.coreutils}/bin/mktemp "$places.XXXXXX")"
            trap '${pkgs.coreutils}/bin/rm -f "$temporary"' EXIT

            ${pkgs.gawk}/bin/awk -v fragment="${place}" '
              function insert_fragment(line) {
                while ((getline line < fragment) > 0) print line
                close(fragment)
                inserted = 1
              }

              !inserted && index($0, "<bookmark href=\"remote:/\">") {
                insert_fragment()
              }

              !inserted && index($0, "</xbel>") {
                insert_fragment()
              }

              { print }
            ' "$places" > "$temporary"

            ${pkgs.coreutils}/bin/chmod --reference="$places" "$temporary"
            ${pkgs.coreutils}/bin/mv "$temporary" "$places"
            trap - EXIT
          fi
        '';
      };
  };
}
