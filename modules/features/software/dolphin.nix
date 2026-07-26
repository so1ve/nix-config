{
  ray.features."software/dolphin" = {
    nixos = {
      services.udisks2.enable = true;
    };

    home =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        waydroidPlace = pkgs.writeText "dolphin-waydroid-place.xbel" ''
           <bookmark href="file://${config.home.homeDirectory}/Waydroid">
            <title>Waydroid</title>
            <info>
             <metadata owner="http://freedesktop.org">
              <bookmark:icon name="waydroid"/>
             </metadata>
             <metadata owner="http://www.kde.org">
              <ID>nix-waydroid-storage</ID>
             </metadata>
            </info>
           </bookmark>
        '';
      in
      {
        home.packages = with pkgs.kdePackages; [
          ark
          breeze-icons
          dolphin
          ffmpegthumbs
          kdegraphics-thumbnailers
          kio-admin
          kio-extras
        ];

        xdg.mimeApps = {
          enable = true;
          defaultApplications."inode/directory" = "org.kde.dolphin.desktop";
        };

        home.activation.pinWaydroidInDolphin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          places="${config.home.homeDirectory}/.local/share/user-places.xbel"
          href="file://${config.home.homeDirectory}/Waydroid"

          if [ -f "$places" ] && ! ${pkgs.gnugrep}/bin/grep -Fq "$href" "$places"; then
            temporary="$(${pkgs.coreutils}/bin/mktemp "$places.XXXXXX")"
            trap '${pkgs.coreutils}/bin/rm -f "$temporary"' EXIT

            ${pkgs.gawk}/bin/awk -v fragment="${waydroidPlace}" '
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
