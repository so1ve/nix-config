{
  ray.features."software/qbittorrent" = {
    home = { pkgs, ... }: {
      home.packages = [ pkgs.qbittorrent ];
    };
  };
}
