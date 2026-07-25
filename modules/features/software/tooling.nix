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
          nodejs
          python3
          ripgrep
          rustup
          tree-sitter
          unzip
          wget
          wl-clipboard
        ];
      };
  };
}
