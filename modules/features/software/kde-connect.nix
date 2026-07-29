{
  ray.features."software/kde-connect" = {
    nixos = {
      programs.kdeconnect = {
        enable = true;
        package = null;
      };
    };

    home = {
      services.kdeconnect = {
        enable = true;
        indicator = true;
      };
    };
  };
}
