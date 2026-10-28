{
  ray.features."software/tooling" = {
    home =
      _:
      {
        mkDotfilesSource,
        pkgs,
        ...
      }:
      {
        home.packages = with pkgs; [
          btop
          fastfetch
          fd
          hyperfine
          jq
          just
          nvd
          ripgrep
          tealdeer
          tokei
          unzip
          wget
          wl-clipboard
        ];

        xdg.configFile."fastfetch/config.jsonc".source = mkDotfilesSource "fastfetch/config.jsonc";
      };
  };
}
