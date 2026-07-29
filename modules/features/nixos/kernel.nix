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
    "nixos/kernel/lts" = kernel "linuxPackages";
    "nixos/kernel/latest" = kernel "linuxPackages_latest";
    "nixos/kernel/testing" = kernel "linuxPackages_testing";
    "nixos/kernel/zen" = kernel "linuxPackages_zen";
    "nixos/kernel/xanmod" = kernel "linuxPackages_xanmod";
    "nixos/kernel/xanmod-latest" = kernel "linuxPackages_xanmod_latest";
  };
}
