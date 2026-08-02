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
          inputs.so1ve.packages.${pkgs.stdenv.hostPlatform.system}.r-maple-mono-nf-cn
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
