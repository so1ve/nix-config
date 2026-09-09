{
  ray.features."software/bitnp" = {
    requires = [ "software/wireguard" ];

    nixos =
      { lib, pkgs, ... }:
      let
        domains = [
          "whoami.bitnp.net"
          "paste.bitnp.net"
          "send.bitnp.net"
          "login.bitnp.net"
        ];

        bitnpEnv = pkgs.writeShellApplication {
          name = "bitnp-env";
          runtimeInputs = [
            pkgs.gnused
            pkgs.systemd
          ];
          text = ''
            if (( $# > 1 )); then
              echo "Usage: bitnp-env [test|prod|status]" >&2
              exit 1
            fi

            mode="''${1:-status}"
            case "$mode" in
              test|prod)
                if (( EUID != 0 )); then
                  exec /run/wrappers/bin/sudo "$0" "$mode"
                fi

                if [[ "$mode" == test ]]; then
                  systemctl start wg-quick-school.service
                  sed -i '/^# profile\.off bitnp-test$/,/^# end$/ {
                    s/^# profile\.off bitnp-test$/# profile.on bitnp-test/
                    s/^# 192\.168\.2\.143 /192.168.2.143 /
                  }' /etc/hosts
                else
                  sed -i '/^# profile\.on bitnp-test$/,/^# end$/ {
                    s/^# profile\.on bitnp-test$/# profile.off bitnp-test/
                    s/^192\.168\.2\.143 /# 192.168.2.143 /
                  }' /etc/hosts
                fi
                echo "Hosts updated."
                ;;
              status) ;;
              -h|--help)
                echo "Usage: bitnp-env [test|prod|status]"
                echo "test: start school WireGuard and use 192.168.2.143 for BITNP services"
                echo "prod: restore normal DNS resolution for BITNP services"
                echo "status: show the local hosts override (default)"
                exit 0
                ;;
              *)
                echo "Usage: bitnp-env [test|prod|status]" >&2
                exit 1
                ;;
            esac

            echo "bitnp-test on = test (192.168.2.143); off = production (DNS)"
            sed -n '/^# profile\.\(on\|off\) bitnp-test$/,/^# end$/p' /etc/hosts
          '';
        };
      in
      {
        # Keep /etc/hosts writable by root so switching does not need a rebuild.
        # System activation restores this disabled profile (production mode).
        environment.etc.hosts.mode = "0644";
        networking.extraHosts = ''
          # profile.off bitnp-test
          ${lib.concatMapStringsSep "\n" (domain: "# 192.168.2.143 ${domain}") domains}
          # end
        '';

        environment.systemPackages = [ bitnpEnv ];
      };
  };
}
