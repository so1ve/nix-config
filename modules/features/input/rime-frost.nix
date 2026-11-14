let
  frost = import ../../../lib/mk-rime.nix {
    schema = "rime_frost";
    dataPackage = pkgs: pkgs.so1ve.rime-frost;
  };
in
{
  ray.features = {
    "input/rime-frost" = frost;
  };
}
