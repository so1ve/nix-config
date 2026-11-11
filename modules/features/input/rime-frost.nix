let
  frost = import ../../../lib/mk-rime.nix {
    schema = "rime_frost";
    dataPackage = packages: packages.rime-frost;
  };
in
{
  ray.features = {
    "input/rime-frost" = frost;
  };
}
