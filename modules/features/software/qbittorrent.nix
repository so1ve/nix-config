{
  ray.features."software/qbittorrent" = {
    home = _: { pkgs, ... }: {
      home.packages = [ pkgs.qbittorrent ];
    };
  };
}
