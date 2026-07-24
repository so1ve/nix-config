{
  ray.features."software/tooling" = {
    home =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          btop
          fd
          gcc
          nodejs
          python3
          ripgrep
          tree-sitter
          unzip
          wget
          wl-clipboard
        ];
      };
  };
}
