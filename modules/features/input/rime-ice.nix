{
  ray.features."input/rime-ice" = {
    nixos =
      { pkgs, ... }:
      {
        ray.input.rime.dataPackages = [ pkgs.rime-ice ];
      };

    home = {
      ray.input.rime = {
        schemas = [ "rime_ice" ];
        suggestedDefaults = [ "rime_ice_suggestion" ];
      };
    };
  };
}
