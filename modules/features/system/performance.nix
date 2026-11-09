{
  ray.features."system/performance" = {
    nixos = _: {
      boot.kernel.sysctl = {
        "vm.swappiness" = 100;
        "vm.page-cluster" = 0;
        "vm.vfs_cache_pressure" = 50;
      };

      services.scx-loader = {
        enable = true;
        config = {
          default_sched = "scx_lavd";
          scheds.scx_lavd.auto_mode = [ "--autopower" ];
        };
      };

      systemd.settings.Manager = {
        DefaultTimeoutStartSec = "15s";
        DefaultTimeoutStopSec = "10s";
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
