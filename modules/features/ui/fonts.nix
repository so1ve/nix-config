{
  ray.features."ui/fonts" = {
    nixos =
      {
        lib,
        pkgs,
        ...
      }:
      {
        fonts.packages = [
          pkgs.nur.repos.so1ve.r-maple-mono-nf-cn
          pkgs.noto-fonts-cjk-sans
          pkgs.noto-fonts-cjk-serif
        ];

        fonts.fontconfig.defaultFonts = {
          sansSerif = lib.mkAfter [ "Noto Sans CJK SC" ];
          serif = lib.mkAfter [ "Noto Serif CJK SC" ];
        };
      };
  };
}
