{ lib, ... }:

{
  ray.features."services/ddns-go" = {
    options = {
      settings = lib.mkOption {
        type = lib.types.attrs;
        description = "ddns-go configuration. Secret values may use { _secret = runtimeFile; }.";
      };
      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional ddns-go command-line arguments.";
      };
    };

    nixos = { settings, ... }: { pkgs, utils, ... }: {
      systemd.services.ddns-go = {
        description = "Dynamic DNS updater";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        path = [ pkgs.bash ];
        preStart = utils.genJqSecretsReplacementSnippet settings.settings "/run/ddns-go/config.json";
        serviceConfig = {
          ExecStart = lib.escapeShellArgs (
            [
              (lib.getExe pkgs.ddns-go)
              "-c"
              "/run/ddns-go/config.json"
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
