{
  ray.features."system/server" = {
    requires.allOf = [
      "system/core"
      "security/sudo"
      "software/tailscale"
    ];

    nixos =
      _:
      { username, ... }:
      {
        networking = {
          nftables.enable = true;
          firewall.enable = true;
        };

        services = {
          openssh = {
            enable = true;
            settings = {
              AllowUsers = [ username ];
              AllowAgentForwarding = false;
              PasswordAuthentication = false;
              KbdInteractiveAuthentication = false;
              PermitRootLogin = "no";
            };
          };
        };
      };
  };
}
