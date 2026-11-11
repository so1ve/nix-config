{ lib, ... }:
{
  ray.features."desktop/we-layerd" = {
    requires.allOf = [ "desktop/niri" ];

    nixos =
      _:
      { inputs, pkgs, ... }:
      let
        package = inputs.we-layerd.packages.${pkgs.stdenv.hostPlatform.system}.default;
      in
      {
        environment.systemPackages = [ package ];
        systemd.packages = [ package ];
      };
  };

  ray.features."desktop/waywallen" = {
    requires.allOf = [ "desktop/niri" ];

    options.plugins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Waywallen plugins";
    };

    home =
      { settings, ... }:
      { inputs, pkgs, ... }:
      {
        home.packages = [
          ((import inputs.so1ve { inherit pkgs; }).waywallen.override {
            inherit (settings) plugins;
          })
        ];
      };
  };
}
