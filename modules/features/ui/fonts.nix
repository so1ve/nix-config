{
  ray.features."ui/fonts" = {
    nixos =
      {
        inputs,
        lib,
        pkgs,
        ...
      }:
      {
        fonts.packages = [
          (import inputs.so1ve { inherit pkgs; }).r-maple-mono-nf-cn
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
