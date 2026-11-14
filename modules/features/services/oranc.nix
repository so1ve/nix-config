{ lib, ... }:

{
  ray.features."services/oranc" = {
    requires.allOf = [ "services/cloudflared" ];

    options = {
      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Start the oranc cache proxy automatically.";
      };

      domain = lib.mkOption {
        type = lib.types.str;
        description = "HTTPS domain of the public Nix binary cache.";
      };

      repository = lib.mkOption {
        type = lib.types.str;
        description = "Public GHCR repository containing the cache, as owner/package.";
      };
    };

    nixos =
      { settings, ... }:
      { inputs, pkgs, ... }:
      {
        imports = [ inputs.oranc.nixosModules.oranc ];

        services.oranc = {
          enable = true;
          package = inputs.oranc.packages.${pkgs.stdenv.hostPlatform.system}.oranc.overrideAttrs (old: {
            # FIXME: Remove after https://github.com/linyinfeng/oranc/pull/40 is merged and released
            # Let the CDN see the blob size before it starts caching the response.
            patches = (old.patches or [ ]) ++ [ ./oranc/content-length.patch ];
          });
          listen = "127.0.0.1:8080";
          log = "oranc=warn";
        };

        systemd.services.oranc = {
          wantedBy = lib.mkForce (lib.optional settings.autoStart "multi-user.target");
          serviceConfig = {
            Restart = "always";
            RestartSec = "5s";
          };
        };

        services.caddy = {
          enable = true;
          virtualHosts."http://${settings.domain}:8081".extraConfig = ''
            bind 127.0.0.1
            @read method GET HEAD
            handle @read {
              reverse_proxy 127.0.0.1:8080 {
                rewrite /ghcr.io/${settings.repository}{path}?
                header_up -Authorization
              }
            }
            respond "Method Not Allowed" 405
          '';
        };
      };
  };
}
