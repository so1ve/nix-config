{
  ray.features."software/wireguard" = {
    requires = [ "security/agenix" ];

    nixos =
      { config, inputs, ... }:
      {
        age.secrets.wireguard-private-key.file = "${inputs.self}/secrets/wireguard-private-key.age";

        networking.wg-quick.interfaces.school = {
          address = [ "192.168.66.3/32" ];
          privateKeyFile = config.age.secrets.wireguard-private-key.path;

          peers = [
            {
              publicKey = "nbpoSOiKhM2Yy58dGsRp5ORxTzKJtD0lSel5CjP9hGs=";
              allowedIPs = [
                "192.168.66.1/32"
                "192.168.2.143/32"
              ];
              endpoint = "10.1.139.2:51821";
              persistentKeepalive = 25;
            }
          ];
        };
      };

    home = {
      programs.ssh = {
        enable = true;
        settings = {
          bitnp-prod = {
            HostName = "bit-staging.bitnp.net";
            User = "bitnp";
            # Port = 8022;
          };
          bitnp-staging = {
            HostName = "192.168.2.126";
            User = "root";
            Port = 8022;
            ProxyJump = "bitnp-prod";
          };
        };
      };

      programs.fish.shellAbbrs = {
        wgup = "sudo systemctl start wg-quick-school.service";
        wgdown = "sudo systemctl stop wg-quick-school.service";
        wgstatus = "sudo wg show school";
        wglog = "sudo journalctl -u wg-quick-school.service -b -e";
      };
    };
  };
}
