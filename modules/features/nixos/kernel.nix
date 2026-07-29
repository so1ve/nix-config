let
  kernel = package: {
    nixos =
      { pkgs, ... }:
      {
        boot.kernelPackages = pkgs.${package};
        boot.kernelParams = [
          "quiet"
          "loglevel=3"
          "udev.log_level=3"
          "rd.udev.log_level=3"
          "systemd.show_status=auto"
        ];
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
