{
  ray.features."software/git/github" = {
    requires.allOf = [ "software/git" ];

    home =
      _:
      { ... }:
      {
        programs.gh = {
          enable = true;
          settings.git_protocol = "ssh";
        };
      };
  };
}
