{ lib, ... }:

{
  ray.features."services/ddns-go" = {
    options = {
      configFile = lib.mkOption {
        type = lib.types.str;
        description = "Runtime ddns-go configuration file supplied by the host.";
      };
      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional ddns-go command-line arguments.";
      };
    };

    nixos = { settings, ... }: { pkgs, ... }: {
      systemd.services.ddns-go = {
        description = "Dynamic DNS updater";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        path = [ pkgs.bash ];
        serviceConfig = {
          ExecStart = lib.escapeShellArgs (
            [
              (lib.getExe pkgs.ddns-go)
              "-c"
              settings.configFile
            ]
            ++ settings.extraArgs
          );
          Restart = "on-failure";
          DynamicUser = true;
          RuntimeDirectory = "ddns-go";
          RuntimeDirectoryMode = "0700";
          UMask = "0077";
        };
      };
    };
  };
}
