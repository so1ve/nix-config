{
  ray.features."hardware/uefi-systemd-boot" = {
    nixos = {
      boot.loader = {
        systemd-boot = {
          enable = true;
          # consoleMode = "1";
        };
        efi.canTouchEfiVariables = true;
      };
    };
  };
}
