{ lib, ... }:

{
  ray.features."services/forgejo" = {
    requires.allOf = [
      "security/agenix"
      "virtualisation/podman"
      "services/pocket-id"
      "services/cloudflared"
    ];

    options = {
      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Start Forgejo and configure its Pocket ID login source automatically.";
      };

      domain = lib.mkOption {
        type = lib.types.str;
        description = "Public hostname served for Forgejo.";
      };

      pocketIdUrl = lib.mkOption {
        type = lib.types.str;
        description = "Public base URL of the Pocket ID instance.";
      };

      adminUsername = lib.mkOption {
        type = lib.types.str;
        description = "Username of the initial Forgejo administrator.";
      };

      adminEmail = lib.mkOption {
        type = lib.types.str;
        description = "Email address of the initial Forgejo administrator.";
      };
    };

    nixos =
      settings:
      {
        config,
        pkgs,
        ...
      }:
      let
        inherit (config.virtualisation.quadlet) containers networks;
      in
      {
        systemd.tmpfiles.rules = [
          "d /var/lib/forgejo 0700 1000 1000 - -"
        ];

        virtualisation.quadlet.containers.forgejo = {
          inherit (settings) autoStart;
          unitConfig = {
            Requires = containers.cloudflared.ref;
            After = containers.cloudflared.ref;
          };
          serviceConfig = {
            Restart = "always";
            TimeoutStartSec = "5min";
          };
          containerConfig = {
            ContainerName = "forgejo";
            Image = "codeberg.org/forgejo/forgejo:latest";
            User = "1000:1000";
            Network = [ networks.cloudflared.ref ];
            NetworkAlias = [ "forgejo" ];
            NoNewPrivileges = true;
            DropCapability = [ "ALL" ];
            Volume = [ "/var/lib/forgejo:/data" ];
            Environment = {
              USER_UID = "1000";
              USER_GID = "1000";
              FORGEJO__server__ROOT_URL = "https://${settings.domain}/";
              FORGEJO__server__DOMAIN = settings.domain;
              FORGEJO__server__HTTP_PORT = "3000";
              FORGEJO__server__DISABLE_SSH = "true";
              FORGEJO__server__START_SSH_SERVER = "false";
              FORGEJO__repository__DEFAULT_BRANCH = "main";
              FORGEJO__security__INSTALL_LOCK = "true";
              FORGEJO__oauth2_client__ENABLE_AUTO_REGISTRATION = "true";
              FORGEJO__service__DISABLE_REGISTRATION = "true";
              FORGEJO__service__REQUIRE_SIGNIN_VIEW = "true";
            };
            EnvironmentFile = [ config.age.secrets.forgejo-env.path ];
          };
        };

        systemd.services = {
          forgejo.restartTriggers = [ config.age.secrets.forgejo-env.file ];
        }
        // lib.optionalAttrs settings.autoStart {
          forgejo-oidc-setup = {
            description = "Create the Forgejo administrator and Pocket ID OIDC source";
            wantedBy = [ "multi-user.target" ];
            requires = [ "forgejo.service" ];
            after = [ "forgejo.service" ];
            path = with pkgs; [
              bash
              gawk
              podman
            ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              TimeoutStartSec = "5min";
              EnvironmentFile = config.age.secrets.forgejo-env.path;
              LoadCredential = "forgejo-oidc-client-secret:${config.age.secrets.forgejo-oidc-client-secret.path}";
            };
            restartTriggers = [
              config.age.secrets.forgejo-env.file
              config.age.secrets.forgejo-oidc-client-secret.file
            ];
            script = ''
              set -eu

              forgejo() {
                podman exec forgejo forgejo "$@"
              }

              users=""
              for _ in {1..60}; do
                if users="$(forgejo admin user list 2>/dev/null)"; then
                  break
                fi
                sleep 2
              done
              test -n "$users"

              if ! printf '%s\n' "$users" | awk -v username=${lib.escapeShellArg settings.adminUsername} '$2 == username { found = 1 } END { exit !found }'; then
                podman exec \
                  --env FORGEJO_ADMIN_PASSWORD \
                  forgejo forgejo admin user create \
                  --username ${lib.escapeShellArg settings.adminUsername} \
                  --password "$FORGEJO_ADMIN_PASSWORD" \
                  --email ${lib.escapeShellArg settings.adminEmail} \
                  --admin \
                  --must-change-password=false
              fi

              auth_sources="$(
                forgejo admin auth list \
                  --min-width 0 \
                  --tab-width 1 \
                  --padding 0 \
                  --pad-char " "
              )"
              auth_source_id="$(
                printf '%s\n' "$auth_sources" |
                  awk '$2 == "pocket-id" { print $1; exit }'
              )"

              configure_oauth() {
                action="$1"
                shift

                podman exec \
                  --env FORGEJO_OIDC_CLIENT_SECRET \
                  forgejo sh -c '
                    exec forgejo admin auth "$@" --secret "$FORGEJO_OIDC_CLIENT_SECRET"
                  ' sh "$action" \
                    "$@" \
                    --name pocket-id \
                    --provider openidConnect \
                    --key forgejo \
                    --auto-discover-url ${lib.escapeShellArg "${settings.pocketIdUrl}/.well-known/openid-configuration"} \
                    --scopes openid \
                    --scopes profile \
                    --scopes email \
                    --skip-local-2fa
              }

              FORGEJO_OIDC_CLIENT_SECRET="$(
                <"$CREDENTIALS_DIRECTORY/forgejo-oidc-client-secret"
              )"
              export FORGEJO_OIDC_CLIENT_SECRET

              if test -n "$auth_source_id"; then
                configure_oauth update-oauth --id "$auth_source_id"
              else
                configure_oauth add-oauth
              fi
            '';
          };
        };
      };
  };
}
