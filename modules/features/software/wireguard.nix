{
  ray.features."software/wireguard".nixos =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.wireguard-tools ];
    };
}
