{
  ray.features."hardware/atk-f1-ultimate" = {
    nixos =
      { pkgs, ... }:
      let
        udevRules = pkgs.writeTextDir "lib/udev/rules.d/70-atk-f1-ultimate.rules" ''
          SUBSYSTEM=="hidraw", KERNEL=="hidraw*", ATTRS{idVendor}=="373b", ATTRS{idProduct}=="11d9|11e4", MODE="0660", TAG+="uaccess"
        '';
      in
      {
        services.udev.packages = [ udevRules ];
      };
  };
}
