{
  ray.features."software/qq" = {
    home =
      { pkgs, ... }:
      {
        # FIXME: revert this after upstream fixes the Wayland issue
        home.packages = [
          (pkgs.qq.override {
            commandLineArgs = "--ozone-platform=wayland";
          })
        ];
      };
  };
}
