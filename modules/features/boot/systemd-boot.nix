{
  ray.features."boot/systemd-boot" = {
    nixos = {
      boot.loader = {
        timeout = 1;
        systemd-boot = {
          configurationLimit = 10;
          enable = true;
          # consoleMode = "1";
        };
        efi.canTouchEfiVariables = true;
      };
    };
  };
}
