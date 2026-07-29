{
  ray.features."nixos/performance" = {
    nixos =
      { pkgs, ... }:
      {
        boot.kernel.sysctl = {
          "vm.swappiness" = 100;
          "vm.page-cluster" = 0;
          "vm.vfs_cache_pressure" = 50;
        };

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
