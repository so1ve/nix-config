let
  mountPoint = "/mnt/nas";
in
{
  ray.features."storage/mount/nas" = {
    nixos =
      {
        config,
        pkgs,
        username,
        ...
      }:
      {
        age.secrets.nas-smb-credentials = {
          file = ../../../../secrets/nas-smb-credentials.age;
          mode = "0400";
        };

        environment.systemPackages = [ pkgs.cifs-utils ];

        fileSystems.${mountPoint} = {
          device = "//192.168.10.60/data";
          fsType = "cifs";
          options = [
            "credentials=${config.age.secrets.nas-smb-credentials.path}"
            "uid=${username}"
            "gid=users"
            "file_mode=0644"
            "dir_mode=0755"
            "vers=3.1.1"
            "_netdev"
            "nofail"
            "noauto"
            "x-systemd.automount"
            # Keep the share mounted once accessed.  This avoids unnecessary
            # CIFS teardown races while the system is running.
            "x-systemd.mount-timeout=10s"
          ];
        };
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
