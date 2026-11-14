{
  config,
  inputs,
  lib,
  ...
}:

let
  inherit (lib) mkOption types;

  json = (inputs.nixpkgs.legacyPackages.x86_64-linux.formats.json { }).type;

  recordType = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = "Relative DNS name, or @ for the zone apex.";
      };

      type = mkOption {
        type = types.str;
      };

      content = mkOption {
        type = types.nullOr types.str;
        default = null;
      };

      ttl = mkOption {
        type = types.ints.unsigned;
        default = 300;
      };

      priority = mkOption {
        type = types.nullOr types.ints.unsigned;
        default = null;
      };

      data = mkOption {
        type = types.attrsOf json;
        default = { };
      };

      comment = mkOption {
        type = types.nullOr types.str;
        default = null;
      };

      lifecycle = mkOption {
        type = types.attrsOf json;
        default = { };
      };

      cloudflare = {
        proxied = mkOption {
          type = types.bool;
          default = false;
        };

        settings = mkOption {
          type = types.attrsOf json;
          default = { };
        };
      };
    };
  };

  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  provider = pkgs.terraform-providers.cloudflare_cloudflare;
  tofu = pkgs.opentofu.withPlugins (_: [ provider ]);

  resources = import ../../lib/dns.nix {
    inherit lib;
    inherit (config.ray) dns cloudflare;
  };

  terraformConfig = inputs.terranix.lib.terranixConfiguration {
    inherit system;
    modules = [
      resources
      {
        terraform.required_providers.cloudflare = {
          source = "registry.opentofu.org/cloudflare/cloudflare";
          version = provider.version;
        };
        provider.cloudflare = { };
      }
    ];
  };

  dnsCommand = pkgs.writeShellApplication {
    name = "dns";
    runtimeInputs = [
      tofu
      pkgs.coreutils
    ];
    text = ''
      umask 077
      workdir="''${DNS_STATE_DIR:-$PWD/.dns}"
      mkdir -p "$workdir"
      install -m 600 ${terraformConfig} "$workdir/config.tf.json"
      tofu -chdir="$workdir" init -input=false -upgrade >&2
      exec tofu -chdir="$workdir" "$@"
    '';
  };
in
{
  options.ray = {
    dns.zones = mkOption {
      default = { };
      type = types.attrsOf (
        types.submodule {
          options = {
            provider = mkOption { type = types.enum [ "cloudflare" ]; };

            cloudflare.zoneId = mkOption { type = types.str; };

            records = mkOption {
              type = types.attrsOf recordType;
              default = { };
            };
          };
        }
      );
    };

    cloudflare = {
      accountId = mkOption {
        type = types.nullOr types.str;
        default = null;
      };

      tunnels = mkOption {
        default = { };
        type = types.attrsOf (
          types.submodule {
            options = {
              id = mkOption { type = types.str; };

              ingress = mkOption {
                type = types.attrsOf (
                  types.submodule {
                    options = {
                      service = mkOption { type = types.str; };

                      originRequest.httpHostHeader = mkOption {
                        type = types.nullOr types.str;
                        default = null;
                      };
                    };
                  }
                );
                default = { };
              };
            };
          }
        );
      };
    };
  };

  config.outputs = _: {
    packages.${system}.dns = dnsCommand;

    checks.${system}.dns =
      let
        failures = import ../../tests/dns.nix { inherit lib; };
      in
      assert lib.assertMsg (failures == [ ]) (builtins.toJSON failures);
      pkgs.runCommand "dns-tests" { } "touch $out";
  };
}
