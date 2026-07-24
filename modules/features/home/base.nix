{
  ray.features."home/base" = {
    home =
      {
        homeStateVersion,
        pkgs,
        username,
        ...
      }:
      {
        home = {
          inherit username;
          homeDirectory = "/home/${username}";
          stateVersion = homeStateVersion;

          packages = with pkgs; [
            btop
            fd
            gcc
            nodejs
            python3
            ripgrep
            tree-sitter
            unzip
            wget

            unstable.codex
          ];

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
