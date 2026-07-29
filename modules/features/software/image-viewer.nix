{
  ray.features = {
    "software/swayimg".home =
      {
        lib,
        pkgs,
        ...
      }:
      {
        home.packages = [ pkgs.swayimg ];

        xdg.mimeApps = {
          enable = true;
          defaultApplications = lib.genAttrs [
            "image/avif"
            "image/bmp"
            "image/gif"
            "image/heic"
            "image/heif"
            "image/jpeg"
            "image/jxl"
            "image/png"
            "image/svg+xml"
            "image/tiff"
            "image/webp"
          ] (_: "swayimg.desktop");
        };
      };

    "software/gwenview".home =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.kdePackages.gwenview ];
      };
  };
}
