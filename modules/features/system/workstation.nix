{
  ray.features."system/workstation" = {
    requires = [ "system/core" ];

    nixos =
      { username, ... }:
      {
        networking.networkmanager.enable = true;
        services.fwupd.enable = true;
        services.printing.enable = true;

        users.users.${username}.extraGroups = [ "networkmanager" ];
      };
  };
}
