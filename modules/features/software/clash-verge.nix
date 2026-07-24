{
  ray.features."software/clash-verge" = {
    nixos =
      { pkgs, ... }:
      {
        programs.clash-verge = {
          enable = true;
          package = pkgs.clash-verge-rev;
          serviceMode = true;
          autoStart = true;
        };
      };
  };
}
