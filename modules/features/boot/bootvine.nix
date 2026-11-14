{
  ray.features."boot/bootvine" = {
    nixos =
      _:
      { inputs, ... }:
      {
        imports = [ inputs.bootvine.nixosModules.default ];

        services.bootvine.enable = true;
      };
  };
}
