{
  ray.features."system/workstation" = {
    requires = [ "system/core" ];

    nixos =
      { username, ... }:
      {
        networking = {
          networkmanager.enable = true;
          nftables.enable = true;
          firewall.enable = true;
        };

        # Desktop services recover naturally when connectivity arrives, so do
        # not hold up boot waiting for NetworkManager to declare itself online.
        systemd.services.NetworkManager-wait-online.enable = false;

        services.fwupd.enable = true;
        services.printing.enable = true;

        users.users.${username}.extraGroups = [ "networkmanager" ];
      };
  };
}
