{
  ray.features."software/gaming" = {
    nixos =
      { pkgs, ... }:
      {
        programs = {
          gamemode.enable = true;
          gamescope.enable = true;

          steam = {
            enable = true;
            extraCompatPackages = with pkgs; [
              dwproton-bin
              proton-ge-bin
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

            protonPackages = with pkgs; [
              dwproton-bin
              proton-ge-bin
            ];
          };

          mangohud.enable = true;
        };
      };
  };
}
