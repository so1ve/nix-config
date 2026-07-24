{
  ray.features."users/ray" = {
    nixos =
      {
        pkgs,
        registry,
        ...
      }:
      let
        user = registry.users.ray;
      in
      {
        users.users.ray = {
          isNormalUser = true;
          inherit (user) description extraGroups;
          shell = pkgs.fish;
        };
      };
  };
}
