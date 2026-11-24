{
  ray.features."software/tooling" = {
    home =
      _:
      {
        inputs,
        mkDotfilesSource,
        pkgs,
        ...
      }:
      {
        home.packages = with pkgs; [
          inputs.uptarn.packages.${pkgs.stdenv.hostPlatform.system}.uptarn
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
