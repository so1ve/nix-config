{
  ray.features."software/tooling" = {
    home =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          btop
          fd
          jq
          just
          ripgrep
          tokei
          unzip
          wget
          wl-clipboard
        ];
      };
  };
}
