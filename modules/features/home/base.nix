{
  ray.features."home/base" = {
    home =
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
