{
  ray.features."hardware/smartd" = {
    nixos = _: { services.smartd.enable = true; };
  };
}
