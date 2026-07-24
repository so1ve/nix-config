{
  ray.features."hardware/uefi-systemd-boot" = {
    nixos = {
      boot.loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };
    };
  };
}
