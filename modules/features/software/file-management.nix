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
        peazip = pkgs.peazip.overrideAttrs (old: {
          postInstall = (old.postInstall or "") + ''
            mkdir -p $out/lib/peazip/res/bin/7z
            ln -s ${lib.getExe pkgs._7zz} $out/lib/peazip/res/bin/7z/7z
          '';
        });

        mkNautilusScript = name: operation: {
          source = pkgs.writeShellScript "peazip-nautilus-${name}" ''
            selected_paths=()
            while IFS= read -r selected_path; do
              if [[ -n "$selected_path" ]]; then
                selected_paths+=("$selected_path")
              fi
            done < <(printf '%s' "''${NAUTILUS_SCRIPT_SELECTED_FILE_PATHS:-}")

            if (( ''${#selected_paths[@]} > 0 )); then
              exec ${lib.getExe peazip} ${operation} "''${selected_paths[@]}"
            fi

            exec ${lib.getExe peazip} ${operation} "$@"
          '';
        };
      in
      {
        home.packages = [ peazip ];

        xdg.dataFile = {
          "nautilus/scripts/PeaZip/添加到压缩包" = mkNautilusScript "add-to-archive" "-add2archive";
          "nautilus/scripts/PeaZip/转换压缩包" = mkNautilusScript "convert" "-add2convert";
          "nautilus/scripts/PeaZip/解压缩" = mkNautilusScript "extract-archive" "-ext2main";
          "nautilus/scripts/PeaZip/解压到此处" = mkNautilusScript "extract-here" "-ext2here";
          "nautilus/scripts/PeaZip/解压到新文件夹" = mkNautilusScript "extract-to-new-folder" "-ext2folder";
          "nautilus/scripts/PeaZip/打开压缩包" = mkNautilusScript "open-archive" "-ext2openasarchive";
          "nautilus/scripts/PeaZip/测试压缩包" = mkNautilusScript "test" "-ext2test";
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
