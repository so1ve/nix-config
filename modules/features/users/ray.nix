{
  ray.features."users/ray" = {
    requires = [ "software/shell" ];

    nixos =
      {
        pkgs,
        user,
        username,
        ...
      }:
      {
        users.users.${username} = {
          isNormalUser = true;
          inherit (user) description extraGroups;
          shell = pkgs.fish;
        };
      };
  };
}
