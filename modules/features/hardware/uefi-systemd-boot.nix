{
  ray.features."hardware/uefi-systemd-boot" = {
    nixos = {
      boot.loader = {
        timeout = 2;
        systemd-boot = {
          enable = true;
          # consoleMode = "1";
        };
        efi.canTouchEfiVariables = true;
      };
    };
  };
}
