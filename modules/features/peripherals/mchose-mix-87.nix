{
  ray.features."peripherals/mchose-mix-87" = {
    nixos =
      { pkgs, ... }:
      let
        udevRules = pkgs.writeTextDir "lib/udev/rules.d/70-mchose-mix-87.rules" ''
          SUBSYSTEM=="hidraw", KERNEL=="hidraw*", ATTRS{idVendor}=="3837", ATTRS{idProduct}=="300d", MODE="0660", TAG+="uaccess"
        '';
      in
      {
        services.udev.packages = [ udevRules ];
      };
  };
}
