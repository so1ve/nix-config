{
  ray.features."software/kelivo".home =
    _:
    { inputs, pkgs, ... }:
    {
      home.packages = [
        (import inputs.so1ve { inherit pkgs; }).kelivo
      ];
    };
}
