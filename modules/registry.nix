{
  ray.registry = {
    users.ray = {
      description = "Ray";
      gitName = "so1ve";
      gitEmail = "58381667+so1ve@users.noreply.github.com";
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
    };

    binaryCaches.noctalia = {
      url = "https://noctalia.cachix.org";
      publicKey = "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=";
    };

    binaryCaches.so1ve = {
      url = "https://so1ve.cachix.org";
      publicKey = "so1ve.cachix.org-1:51jcW4FkJhiLcqPsiUx3nglRP469les8F9zjFxio1nw=";
    };
  };
}
