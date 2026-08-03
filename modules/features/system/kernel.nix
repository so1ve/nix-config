let
  kernel = package: {
    nixos =
      { pkgs, ... }:
      {
        boot.kernelPackages = pkgs.${package};
      };
  };
in
{
  ray.features = {
    "system/kernel/lts" = kernel "linuxPackages";
    "system/kernel/latest" = kernel "linuxPackages_latest";
    "system/kernel/testing" = kernel "linuxPackages_testing";
    "system/kernel/zen" = kernel "linuxPackages_zen";
  };
}
