{
  ray.features."software/thunderbird" = {
    home = { pkgs, ... }: {
      home.packages = [ pkgs.thunderbird ];
    };
  };
}
