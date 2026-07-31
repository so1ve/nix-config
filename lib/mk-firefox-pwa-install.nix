{ lib }:

{
  config,
  pkgs,
  name,
  description,
  manifestUrl,
  installArgs ? [ ],
  waitForManifest ? false,
  timeoutStartSec ? null,
}:

let
  firefoxPwaConfig = "${config.xdg.dataHome}/firefoxpwa/config.json";

  installPwa = pkgs.writeShellScript "install-${name}-pwa" ''
    set -eu

    manifest_url=${lib.escapeShellArg manifestUrl}
    pwa_config=${lib.escapeShellArg firefoxPwaConfig}

    ${lib.optionalString waitForManifest ''
      for attempt in $(${pkgs.coreutils}/bin/seq 1 30); do
        if ${pkgs.curl}/bin/curl --fail --silent --show-error \
          --output /dev/null "$manifest_url"; then
          break
        fi

        if [ "$attempt" -eq 30 ]; then
          exit 1
        fi

        ${pkgs.coreutils}/bin/sleep 1
      done
    ''}

    if [ -f "$pwa_config" ] \
      && ${pkgs.gnugrep}/bin/grep --fixed-strings --quiet \
        "$manifest_url" "$pwa_config"; then
      exit 0
    fi

    exec ${lib.getExe pkgs.firefoxpwa} site install \
      ${lib.escapeShellArgs installArgs} "$manifest_url"
  '';
in
{
  home.packages = [ pkgs.firefoxpwa ];

  programs.firefox.nativeMessagingHosts = [ pkgs.firefoxpwa ];

  systemd.user.services."${name}-pwa-install" = {
    Unit = {
      Description = description;
      After = [ "graphical-session.target" ];
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${installPwa}";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = 10;
    }
    // lib.optionalAttrs (timeoutStartSec != null) {
      TimeoutStartSec = timeoutStartSec;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
