{
  ray.features."software/tooling" = {
    home =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          btop
          fastfetch
          fd
          jq
          just
          nvd
          ripgrep
          tokei
          unzip
          wget
          wl-clipboard
        ];
      };
  };
}
