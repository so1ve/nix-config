let
  kernel = package: {
    nixos =
      { pkgs, ... }:
      {
        boot.kernelPackages = pkgs.${package};
      };
  };

  cachyosKernel = package: {
    nixos =
      { inputs, pkgs, ... }:
      {
        nixpkgs.overlays = [ inputs.nix-cachyos-kernel.overlays.pinned ];
        boot.kernelPackages = pkgs.cachyosKernels.${package};
      };
  };
in
{
  ray.features = {
    "system/kernel/cachyos" = cachyosKernel "linuxPackages-cachyos-latest";
    "system/kernel/cachyos-lto-zen4" = cachyosKernel "linuxPackages-cachyos-latest-lto-zen4";
    "system/kernel/cachyos-lts" = cachyosKernel "linuxPackages-cachyos-lts";
    "system/kernel/cachyos-zen4" = cachyosKernel "linuxPackages-cachyos-latest-zen4";
    "system/kernel/lts" = kernel "linuxPackages";
    "system/kernel/latest" = kernel "linuxPackages_latest";
    "system/kernel/testing" = kernel "linuxPackages_testing";
    "system/kernel/zen" = kernel "linuxPackages_zen";
  };
}
