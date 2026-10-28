{
  ray.features."home/base" = {
    home =
      _:
      {
        homeStateVersion,
        username,
        ...
      }:
      {
        home = {
          inherit username;
          homeDirectory = "/home/${username}";
          stateVersion = homeStateVersion;
        };

        programs.home-manager.enable = true;
      };
  };
}
