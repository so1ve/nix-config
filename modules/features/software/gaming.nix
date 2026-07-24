{
  ray.features."software/gaming" = {
    nixos =
      { pkgs, ... }:
      let
        dwprotonEndfield = pkgs.callPackage ../../../packages/dwproton-endfield.nix { };
      in
      {
        programs = {
          gamemode.enable = true;
          gamescope.enable = true;

          steam = {
            enable = true;
            extraCompatPackages = [
              dwprotonEndfield
              pkgs.proton-ge-bin
            ];
          };
        };
      };

    home =
      {
        osConfig,
        pkgs,
        ...
      }:
      let
        dwprotonEndfield = pkgs.callPackage ../../../packages/dwproton-endfield.nix { };
      in
      {
        home.packages = [ pkgs.hmcl ];

        programs = {
          lutris = {
            enable = true;
            steamPackage = osConfig.programs.steam.package;

            extraPackages = with pkgs; [
              gamemode
              gamescope
              mangohud
              umu-launcher
              winetricks
            ];

            protonPackages = [
              dwprotonEndfield
              pkgs.proton-ge-bin
            ];
          };

          mangohud.enable = true;
        };
      };
  };
}
