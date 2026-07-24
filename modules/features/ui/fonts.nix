{
  ray.features."ui/fonts" = {
    nixos =
      { pkgs, ... }:
      {
        fonts.packages = [
          (pkgs.callPackage ../../../packages/r-maple-mono-nf-cn.nix { })
        ];
      };
  };
}
