{ lib, ... }:
let
  kernels = {
    lts = "linuxPackages";
    latest = "linuxPackages_latest";
    testing = "linuxPackages_testing";
    zen = "linuxPackages_zen";
  };
  cachyosKernels = {
    cachyos = "linuxPackages-cachyos-latest";
    cachyos-zen4 = "linuxPackages-cachyos-latest-zen4";
    cachyos-lto-zen4 = "linuxPackages-cachyos-latest-lto-zen4";
    cachyos-lts = "linuxPackages-cachyos-lts";
    cachyos-lts-lto-zen4 = "linuxPackages-cachyos-lts-lto-zen4";
  };
in
{
  ray.features."system/kernel" = {
    options.variant = lib.mkOption {
      type = lib.types.enum (builtins.attrNames kernels ++ builtins.attrNames cachyosKernels);
      default = "lts";
      description = "Kernel variant to use on this host.";
    };

    nixos =
      settings:
      {
        inputs,
        pkgs,
        ...
      }:
      let
        variant = settings.variant;
        useCachyos = builtins.hasAttr variant cachyosKernels;
      in
      {
        nixpkgs.overlays = lib.optional useCachyos inputs.nix-cachyos-kernel.overlays.pinned;
        boot.kernelPackages =
          if useCachyos then pkgs.cachyosKernels.${cachyosKernels.${variant}} else pkgs.${kernels.${variant}};
      };
  };
}
