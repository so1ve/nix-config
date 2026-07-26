{
  ray.features."software/waydroid" = {
    nixos =
      { pkgs, ... }:
      {
        virtualisation.waydroid = {
          enable = true;
          package = pkgs.waydroid-nftables;
        };
      };
  };
}
