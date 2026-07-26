{
  ray.features."software/tooling" = {
    home =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          btop
          fd
          gcc
          go
          jq
          nodejs
          python3
          ripgrep
          rustup
          tokei
          tree-sitter
          unzip
          wget
          wl-clipboard
        ];
      };
  };
}
