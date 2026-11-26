{ lib, ... }:

{
  ray.features."services/restic" = {
    requires = settings: {
      allOf = [ "security/agenix" ] ++ lib.optional (settings.podman != null) "virtualisation/podman";
    };

    options = {
      mountPoint = lib.mkOption {
        type = lib.types.str;
        description = "NFS mount point that holds the Restic repository.";
      };

      passwordSecret = lib.mkOption {
        type = lib.types.str;
        default = "restic-password";
        description = "Declared agenix secret containing the Restic repository password.";
      };

      paths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional directories to back up.";
      };

      exclude = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Restic exclude patterns.";
      };

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "daily";
        description = "Calendar expression for the backup timer.";
      };

      pruneOpts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Retention options passed to restic forget.";
      };

      podman = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.attrsOf (
            lib.types.submodule {
              options = {
                exclude = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = "Exclude patterns relative to the volume.";
                };

                requiredFiles = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = "Files that must exist and be nonempty before backing up.";
                };
              };
            }
          )
        );
        default = null;
        description = "Back up all declared Podman volumes with optional settings per volume.";
      };
    };

    nixos =
      { settings, ... }:
      {
        config,
        featureEnabled,
        pkgs,
        ...
      }:
      let
        inherit (settings) mountPoint;
        host = config.networking.hostName;
        unit = "restic-backups-${host}";
        runtime = "/run/${unit}";
        exports = "${runtime}/sqlite";
        secret = settings.passwordSecret;
        volumes = if settings.podman == null then { } else config.virtualisation.quadlet.volumes;
        volumeData = volume: "/var/lib/containers/storage/volumes/${volume.podmanName}/_data";
        paths = settings.paths ++ map volumeData (builtins.attrValues volumes);
        volumePolicyPaths =
          key:
          builtins.concatLists (
            lib.mapAttrsToList (
              name: policy: map (path: "${volumeData volumes.${name}}/${path}") policy.${key}
            ) (if settings.podman == null then { } else settings.podman)
          );
        exclude = settings.exclude ++ volumePolicyPaths "exclude";
        snapshotConfig = pkgs.writeText "${unit}-sqlite.json" (
          builtins.toJSON {
            roots = lib.filter (path: path != mountPoint && !lib.hasPrefix "${mountPoint}/" path) paths;
            ignoredDirectories = exclude;
          }
        );
      in
      {
        services.restic.backups.${host} = {
          repository = "${mountPoint}/restic";
          passwordFile = config.age.secrets.${secret}.path;
          initialize = true;
          inherit exclude;
          inherit (settings) pruneOpts;
          paths = paths ++ [ exports ];
          timerConfig = {
            OnCalendar = settings.schedule;
            Persistent = true;
          };
          extraBackupArgs = [
            "--one-file-system"
            "--exclude-caches"
            "--exclude-file=${runtime}/sqlite-excludes"
          ];
          backupPrepareCommand = ''
            #!${pkgs.runtimeShell}
            set -euo pipefail
            umask 077

            if ! source=$(${lib.getExe' pkgs.util-linux "findmnt"} -rn -t nfs,nfs4 -o SOURCE --target ${lib.escapeShellArg mountPoint}) \
              || [[ "$source" != ${lib.escapeShellArg config.fileSystems.${mountPoint}.device} ]]; then
              echo "Expected the configured NFS export at "${lib.escapeShellArg mountPoint} >&2
              exit 1
            fi

            ${lib.concatMapStringsSep "\n" (path: "test -d ${lib.escapeShellArg path}") paths}
            ${lib.concatMapStringsSep "\n" (path: "test -s ${lib.escapeShellArg path}") (
              volumePolicyPaths "requiredFiles"
            )}
            ${lib.getExe pkgs.python3} ${./restic/snapshot-sqlite.py} \
              ${snapshotConfig} ${exports} ${runtime}/sqlite-excludes
          '';
          runCheck = true;
        };

        systemd.services.${unit} = {
          unitConfig.RequiresMountsFor = [ mountPoint ];
          serviceConfig = {
            RuntimeDirectoryMode = "0700";
          };
        };
      }
      // lib.optionalAttrs (featureEnabled "services/uptarn-agent") {
        ray.uptarn.timerJobs = [
          {
            key = "restic";
            label = "${host} Restic";
            unit = "${unit}.service";
            timer = "${unit}.timer";
            inherit (settings) schedule;
          }
        ];
      };
  };
}
