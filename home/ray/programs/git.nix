{ ... }:
{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "so1ve";
        email = "58381667+so1ve@users.noreply.github.com";
      };

      merge.conflictStyle = "zdiff3";
      status.showUntrackedFiles = "all";
    };
  };
}
