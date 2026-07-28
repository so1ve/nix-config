{
  ray.features."users/ray" = {
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
