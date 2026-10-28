{
  ray.features."security/sudo" = {
    nixos =
      _:
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
