{
  ray.features."software/tooling" = {
    home =
      {
        config,
        mkDotfilesSymlink,
        pkgs,
        ...
      }:
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

        xdg.configFile."fastfetch/config.jsonc".source = mkDotfilesSymlink {
          inherit config;
          name = "fastfetch/config.jsonc";
        };
      };
  };
}
