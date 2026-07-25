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
            extraCompatPackages = [ pkgs.proton-ge-bin ];
          };
        };
      };

    home =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.hmcl ];

        programs.mangohud.enable = true;
      };
  };
}
