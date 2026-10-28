{
  ray.features."software/thunderbird" = {
    home = _: { pkgs, ... }: {
      home.packages = [ pkgs.thunderbird ];
    };
  };
}
