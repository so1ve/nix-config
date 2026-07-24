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

          sessionVariables = {
            EDITOR = "nvim";
            VISUAL = "nvim";
            SUDO_EDITOR = "nvim";
          };
        };

        programs.home-manager.enable = true;
      };
  };
}
