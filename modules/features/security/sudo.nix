{
  ray.features."security/sudo" = {
    nixos =
      { username, ... }:
      {
        security.sudo-rs = {
          enable = true;
          execWheelOnly = true;
        };

        users.users.${username}.extraGroups = [ "wheel" ];
      };
  };
}
