{
  ray.features."hardware/graphics" = {
    nixos = _: {
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };
    };
  };
}
