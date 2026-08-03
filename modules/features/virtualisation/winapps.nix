{
  ray.features."virtualisation/winapps" = {
    requires = [ "virtualisation/podman" ];

    nixos =
      {
        username,
        ...
      }:
      {
        systemd.tmpfiles.rules = [
          "d /var/lib/containers/${username}/winapps/storage 0700 ${username} users - -"
          # NOCOW
          "h /var/lib/containers/${username}/winapps/storage - - - - +C"
        ];

        users.users.${username}.extraGroups = [ "kvm" ];
      };

    home =
      {
        config,
        inputs,
        lib,
        pkgs,
        username,
        ...
      }:
      let
        configDirectory = "${config.xdg.configHome}/winapps";
        winappsPackage = inputs.winapps.packages.${pkgs.stdenv.hostPlatform.system}.winapps;
        winappsConfig = pkgs.writeText "winapps.conf" (
          builtins.replaceStrings [ "@username@" ] [ username ] (builtins.readFile ./winapps/winapps.conf)
        );
        winappsVm = pkgs.writeShellApplication {
          name = "winapps-vm";
          runtimeInputs = [
            pkgs.podman
            pkgs.podman-compose
            winappsPackage
          ];
          text = builtins.readFile ./winapps/winapps-vm.sh;
        };
      in
      {
        home.packages = [
          winappsPackage
          winappsVm
          # WinApps invokes this exact executable rather than `podman compose`.
          pkgs.podman-compose
        ];

        xdg.configFile = {
          "winapps/compose.yaml".source = ./winapps/compose.yaml;
          "winapps/oem".source = "${inputs.winapps}/oem";
          "winapps/winapps.conf".source = winappsConfig;
        };

        home.activation.createWinAppsCredentials = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          credentials='${configDirectory}/.env'

          if [[ ! -e "$credentials" ]]; then
            ${pkgs.coreutils}/bin/install -d -m 0700 '${configDirectory}'
            umask 077
            ${pkgs.coreutils}/bin/printf 'USERNAME=%s\nPASSWORD=%s\n' \
              '${username}' \
              "$(${pkgs.openssl}/bin/openssl rand -hex 16)" > "$credentials"
          fi
        '';
      };
  };
}
