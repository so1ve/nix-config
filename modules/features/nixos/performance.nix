{
  ray.features."nixos/performance" = {
    nixos =
      { pkgs, ... }:
      {
        boot.kernelPackages = pkgs.linuxPackages_zen;

        services.scx = {
          enable = true;
          package = pkgs.scx.rustscheds;
          scheduler = "scx_lavd";
          extraArgs = [ "--autopower" ];
        };

        zramSwap = {
          enable = true;
          algorithm = "zstd";
          memoryPercent = 50;
          priority = 100;
        };
      };
  };
}
