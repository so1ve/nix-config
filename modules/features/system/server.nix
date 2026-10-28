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
        users.users.${username}.openssh.authorizedKeys.keyFiles = [
          ../../../keys/ssh-admin-workstation.pub
        ];

        networking = {
          nftables.enable = true;
          firewall.enable = true;
        };

        services = {
          openssh = {
            enable = true;
            settings = {
              PasswordAuthentication = false;
              KbdInteractiveAuthentication = false;
              PermitRootLogin = "no";
            };
          };
        };
      };
  };
}
