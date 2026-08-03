{
  ray.features = {
    "software/dolphin" = {
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
          cfg = config.ray.dolphin;

          places = lib.mapAttrsToList (
            id: place:
            let
              escapedHref = lib.escapeXML place.href;
            in
            {
              fragment = pkgs.writeText "dolphin-place-${id}.xbel" ''
                <bookmark href="${escapedHref}">
                 <title>${lib.escapeXML place.title}</title>
                 <info>
                  <metadata owner="http://freedesktop.org">
                   <bookmark:icon name="${lib.escapeXML place.icon}"/>
                  </metadata>
                  <metadata owner="http://www.kde.org">
                   <ID>${lib.escapeXML id}</ID>
                  </metadata>
                 </info>
                </bookmark>
              '';
              needle = ''<bookmark href="${escapedHref}">'';
            }
          ) cfg.places;

          installPlaces = lib.concatMapStringsSep "\n" (place: ''
            install_place ${lib.escapeShellArg place.needle} ${lib.escapeShellArg "${place.fragment}"}
          '') places;
        in
        {
          options.ray.dolphin.places = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule {
                options = {
                  href = lib.mkOption {
                    type = lib.types.str;
                    description = "URL stored in Dolphin's Places panel.";
                  };
                  title = lib.mkOption {
                    type = lib.types.str;
                    description = "Label shown in Dolphin's Places panel.";
                  };
                  icon = lib.mkOption {
                    type = lib.types.str;
                    description = "Icon name shown in Dolphin's Places panel.";
                  };
                };
              }
            );
            default = { };
            description = "Declarative entries added to Dolphin's mutable Places file.";
          };

          config = {
            home.packages = with pkgs.kdePackages; [
              breeze-icons
              dolphin
              ffmpegthumbs
              kdegraphics-thumbnailers
              kio-admin
              kio-extras
              kservice
            ];

            # KService still builds its application database from applications.menu.
            # Minimal compositors such as Niri do not provide Plasma's menu file.
            xdg.configFile."menus/applications.menu".text = ''
              <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
                "http://www.freedesktop.org/standards/menu-spec/1.0/menu.dtd">
              <Menu>
                <Name>Applications</Name>
                <DefaultAppDirs/>
                <DefaultDirectoryDirs/>
                <DefaultMergeDirs/>
                <Include>
                  <All/>
                </Include>
              </Menu>
            '';

            xdg.mimeApps = {
              enable = true;
              defaultApplications."inode/directory" = "org.kde.dolphin.desktop";
            };

            home.activation.syncDolphinPlaces = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              places="${config.home.homeDirectory}/.local/share/user-places.xbel"

              install_place() {
                needle="$1"
                fragment="$2"

                if ${pkgs.gnugrep}/bin/grep -Fq "$needle" "$places"; then
                  return
                fi

                temporary="$(${pkgs.coreutils}/bin/mktemp "$places.XXXXXX")"
                trap '${pkgs.coreutils}/bin/rm -f "$temporary"' EXIT

                ${pkgs.gawk}/bin/awk -v fragment="$fragment" '
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
              }

              if [ -f "$places" ]; then
                ${installPlaces}
              fi
            '';
          };
        };
    };

    "software/nautilus" = {
      nixos.services = {
        gvfs.enable = true;
        udisks2.enable = true;
      };

      home =
        { pkgs, ... }:
        {
          home.packages = [ pkgs.nautilus ];
        };
    };

    "software/peazip".home =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.peazip ];
      };
  };
}
