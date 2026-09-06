{
  ray.features."software/wireguard" = {
    requires = [ "security/agenix" ];

    nixos =
      { inputs, pkgs, ... }:
      {
        age.secrets.wireguard-private-key.file = "${inputs.self}/secrets/wireguard-private-key.age";

        environment.systemPackages = [ pkgs.wireguard-tools ];
      };
  };
}
