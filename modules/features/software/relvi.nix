{
  ray.features."software/relvi" = {
    requires.anyOf = [
      "desktop/hyprland"
      "desktop/niri"
    ];

    home =
      _:
      { inputs, ... }:
      {
        imports = [ inputs.relvi.homeManagerModules.default ];
        services.relvi.enable = true;
      };
  };
}
