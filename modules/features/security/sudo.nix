{ lib, ... }:

{
  ray.features."security/sudo" = {
    options.wheelNeedsPassword = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Require a password when wheel members use sudo.";
    };

    nixos =
      settings:
      { username, ... }:
      {
        security.sudo-rs = {
          inherit (settings) wheelNeedsPassword;
          enable = true;
          execWheelOnly = true;
        };

        users.users.${username}.extraGroups = [ "wheel" ];
      };
  };
}
