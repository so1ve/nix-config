{
  ray.features."software/tailscale".nixos = {
    services.tailscale = {
      enable = true;
      openFirewall = true;
    };
  };
}
