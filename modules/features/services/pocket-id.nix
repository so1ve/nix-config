{ lib, ... }:

{
  ray.features."services/pocket-id" = {
    requires.allOf = [
      "security/agenix"
      "virtualisation/podman"
      "services/cloudflared"
    ];

    options = {
      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Start Pocket ID and provision its OIDC clients automatically.";
      };

      publicUrl = lib.mkOption {
        type = lib.types.str;
        description = "Public base URL used by Pocket ID for OIDC discovery.";
      };

      clients = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              id = lib.mkOption {
                type = lib.types.str;
                description = "OIDC client ID presented to Pocket ID.";
              };

              name = lib.mkOption {
                type = lib.types.str;
                description = "Human-readable OIDC client name.";
              };

              callbackUrls = lib.mkOption {
                type = lib.types.nonEmptyListOf lib.types.str;
                description = "Allowed OIDC callback URLs.";
              };

              secretName = lib.mkOption {
                type = lib.types.str;
                description = "Name of the agenix secret containing the client secret.";
              };
            };
          }
        );
        default = { };
        description = "OIDC clients kept in sync with Pocket ID.";
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
        clientNames = lib.attrNames settings.clients;
        clientSecretFile = client: config.age.secrets.${client.secretName}.path;
        clientPayload =
          client:
          pkgs.writeText
            "pocket-id-client-${builtins.substring 0 16 (builtins.hashString "sha256" client.id)}.json"
            (
              builtins.toJSON {
                inherit (client) id name callbackUrls;
                description = "";
                logoutCallbackURLs = [ ];
                backchannelLogoutURL = "";
                isPublic = false;
                pkceEnabled = false;
                requiresReauthentication = false;
                requiresPushedAuthorizationRequests = false;
                skipConsent = false;
                credentials = {
                  federatedIdentities = [ ];
                  secrets = [ ];
                };
                launchURL = null;
                hasLogo = false;
                hasDarkLogo = false;
                isGroupRestricted = false;
                accessTokenDurationMinutes = 60;
                refreshTokenDurationMinutes = 43200;
                claimMappingPolicyId = "";
              }
            );
        provisionClient =
          name:
          let
            client = settings.clients.${name};
            payload = clientPayload client;
            secretPath = clientSecretFile client;
            temporaryName = builtins.substring 0 16 (builtins.hashString "sha256" name);
          in
          ''
            client_id=${lib.escapeShellArg client.id}
            encoded_client_id="$(${lib.getExe pkgs.jq} -rn --arg value "$client_id" '$value | @uri')"
            client_path="$api_base/api/oidc/clients/$encoded_client_id"
            client_response="$state_dir/${temporaryName}-client.json"

            status="$(
              ${lib.getExe pkgs.curl} \
                --silent \
                --show-error \
                --output "$client_response" \
                --write-out '%{http_code}' \
                --header "@$header_file" \
                "$client_path"
            )"

            case "$status" in
              200)
                ${lib.getExe pkgs.curl} \
                  --silent \
                  --show-error \
                  --fail-with-body \
                  --request PUT \
                  --header "@$header_file" \
                  --header "Content-Type: application/json" \
                  --data-binary @${payload} \
                  --output /dev/null \
                  "$client_path"
                ;;
              404)
                ${lib.getExe pkgs.curl} \
                  --silent \
                  --show-error \
                  --fail-with-body \
                  --request POST \
                  --header "@$header_file" \
                  --header "Content-Type: application/json" \
                  --data-binary @${payload} \
                  --output /dev/null \
                  "$api_base/api/oidc/clients"
                ;;
              *)
                printf 'Pocket ID returned HTTP %s while reading client %s\n' "$status" "$client_id" >&2
                exit 1
                ;;
            esac
            rm -f "$client_response"

            secrets_response="$state_dir/${temporaryName}-secrets.json"
            ${lib.getExe pkgs.curl} \
              --silent \
              --show-error \
              --fail-with-body \
              --header "@$header_file" \
              --output "$secrets_response" \
              "$client_path/secrets"

            client_secret="$(<${secretPath})"
            test -n "$client_secret"
            old_secret_ids="$(
              ${lib.getExe pkgs.jq} -r \
                '.[] | select(.isActive) | .id' \
                "$secrets_response"
            )"
            secret_request="$state_dir/${temporaryName}-secret-request.json"
            secret_response="$state_dir/${temporaryName}-secret-response.json"
            ${lib.getExe pkgs.jq} -n \
              --rawfile secret ${lib.escapeShellArg secretPath} \
              '{ secret: $secret }' \
              >"$secret_request"
            ${lib.getExe pkgs.curl} \
              --silent \
              --show-error \
              --fail-with-body \
              --request POST \
              --header "@$header_file" \
              --header "Content-Type: application/json" \
              --data-binary "@$secret_request" \
              --output "$secret_response" \
              "$client_path/secrets"
            desired_secret_id="$(${lib.getExe pkgs.jq} -r '.id' "$secret_response")"
            test -n "$desired_secret_id"
            rm -f "$secret_request" "$secret_response"

            while IFS= read -r old_secret_id; do
              test -z "$old_secret_id" && continue
              ${lib.getExe pkgs.curl} \
                --silent \
                --show-error \
                --fail-with-body \
                --request DELETE \
                --header "@$header_file" \
                --output /dev/null \
                "$client_path/secrets/$old_secret_id"
            done <<<"$old_secret_ids"
            rm -f "$secrets_response"
          '';
      in
      {
        age.secrets = {
          pocket-id-env = {
            owner = "1000";
            group = "1000";
            mode = "0400";
          };
        }
        // lib.listToAttrs (
          map (
            name:
            lib.nameValuePair settings.clients.${name}.secretName {
              owner = "1000";
              group = "1000";
              mode = "0400";
            }
          ) clientNames
        );

        systemd.tmpfiles.rules = [
          "d /var/lib/pocket-id 0700 1000 1000 - -"
        ];

        virtualisation.quadlet.containers.pocket-id = {
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
            ContainerName = "pocket-id";
            Image = "docker.io/pocketid/pocket-id:latest";
            User = "1000:1000";
            Network = [ networks.cloudflared.ref ];
            NetworkAlias = [ "pocket-id" ];
            NoNewPrivileges = true;
            DropCapability = [ "ALL" ];
            ReadOnly = true;
            Volume = [ "/var/lib/pocket-id:/app/data" ];
            Environment = {
              APP_URL = settings.publicUrl;
              TRUST_PROXY = "true";
              ALLOW_USER_SIGNUPS = "open";
              UI_CONFIG_DISABLED = "true";
              AUTO_CREATE_OIDC_CLIENT_SECRET = "false";
            };
            EnvironmentFile = [ config.age.secrets.pocket-id-env.path ];
          };
        };

        systemd.services = {
          pocket-id.restartTriggers = [ config.age.secrets.pocket-id-env.file ];
        }
        // lib.optionalAttrs settings.autoStart {
          pocket-id-setup = {
            description = "Provision Pocket ID OIDC clients";
            wantedBy = [ "multi-user.target" ];
            requires = [ "pocket-id.service" ];
            after = [ "pocket-id.service" ];
            path = with pkgs; [
              bash
              coreutils
              curl
              jq
            ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              TimeoutStartSec = "5min";
              UMask = "0077";
              RuntimeDirectory = "pocket-id-setup";
              RuntimeDirectoryMode = "0700";
              EnvironmentFile = config.age.secrets.pocket-id-env.path;
            };
            restartTriggers = [
              config.age.secrets.pocket-id-env.file
            ]
            ++ map (name: config.age.secrets.${settings.clients.${name}.secretName}.file) clientNames;
            script = ''
              set -euo pipefail

              api_base=http://pocket-id:1411
              state_dir="$RUNTIME_DIRECTORY"
              header_file="$state_dir/api-header"
              printf 'X-API-Key: %s\n' "$STATIC_API_KEY" >"$header_file"

              attempt=0
              until ${lib.getExe pkgs.curl} \
                --silent \
                --fail \
                "$api_base/healthz" \
                >/dev/null; do
                attempt=$((attempt + 1))
                if ((attempt >= 90)); then
                  echo "Pocket ID did not become healthy" >&2
                  exit 1
                fi
                sleep 2
              done

              ${lib.concatMapStringsSep "\n" provisionClient clientNames}
            '';
          };
        };
      };
  };
}
