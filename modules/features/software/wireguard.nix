{
  ray.features."software/wireguard".nixos =
    _:
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.wireguard-tools ];
    };
}
