{
  ray.features."software/git" = {
    home =
      {
        registry,
        username,
        ...
      }:
      let
        user = registry.users.${username};
      in
      {
        programs.git = {
          enable = true;

          settings = {
            user = {
              name = user.gitName;
              email = user.gitEmail;
            };

            merge.conflictStyle = "zdiff3";
            status.showUntrackedFiles = "all";
          };
        };
      };
  };
}
