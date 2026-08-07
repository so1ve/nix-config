{
  ray.features."software/git" = {
    home =
      { user, ... }:
      {
        programs.git = {
          enable = true;
          settings = {
            core = {
              autocrlf = false;
              eol = "lf";
            };

            init.defaultBranch = "main";
            merge.conflictStyle = "zdiff3";
            pull.rebase = true;
            push.autoSetupRemote = true;
            status.showUntrackedFiles = "all";

            user = {
              name = user.gitName;
              email = user.gitEmail;
            };
          };
        };
      };
  };
}
