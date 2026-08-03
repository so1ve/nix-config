{
  ray.features = {
    "software/nautilus" = {
      nixos.services = {
        gvfs.enable = true;
        udisks2.enable = true;
      };

      home =
        { pkgs, ... }:
        {
          home.packages = [ pkgs.nautilus ];

          xdg.mimeApps = {
            enable = true;
            defaultApplications."inode/directory" = "org.gnome.Nautilus.desktop";
          };
        };
    };

    "software/peazip".home =
      {
        lib,
        pkgs,
        ...
      }:
      let
        mkNautilusScript = name: operation: {
          source = pkgs.writeShellScript "peazip-nautilus-${name}" ''
            selected_paths=()
            while IFS= read -r selected_path; do
              if [[ -n "$selected_path" ]]; then
                selected_paths+=("$selected_path")
              fi
            done < <(printf '%s' "''${NAUTILUS_SCRIPT_SELECTED_FILE_PATHS:-}")

            if (( ''${#selected_paths[@]} > 0 )); then
              exec ${lib.getExe pkgs.peazip} ${operation} "''${selected_paths[@]}"
            fi

            exec ${lib.getExe pkgs.peazip} ${operation} "$@"
          '';
        };
      in
      {
        home.packages = [ pkgs.peazip ];

        xdg.dataFile = {
          "nautilus/scripts/PeaZip/Add to Archive" = mkNautilusScript "add-to-archive" "-add2archive";
          "nautilus/scripts/PeaZip/Convert" = mkNautilusScript "convert" "-add2convert";
          "nautilus/scripts/PeaZip/Extract Archive" = mkNautilusScript "extract-archive" "-ext2main";
          "nautilus/scripts/PeaZip/Extract Here" = mkNautilusScript "extract-here" "-ext2here";
          "nautilus/scripts/PeaZip/Extract to New Folder" =
            mkNautilusScript "extract-to-new-folder" "-ext2folder";
          "nautilus/scripts/PeaZip/Open Archive" = mkNautilusScript "open-archive" "-ext2openasarchive";
          "nautilus/scripts/PeaZip/Test" = mkNautilusScript "test" "-ext2test";
        };

        xdg.mimeApps = {
          enable = true;
          defaultApplications = lib.genAttrs [
            "application/bzip2"
            "application/gzip"
            "application/vnd.rar"
            "application/x-7z-compressed"
            "application/x-bzip-compressed-tar"
            "application/x-compressed-tar"
            "application/x-gzip"
            "application/x-rar"
            "application/x-rar-compressed"
            "application/x-tar"
            "application/x-xz"
            "application/x-xz-compressed-tar"
            "application/zip"
          ] (_: "peazip.desktop");
        };
      };
  };
}
