{
  ray.features."software/kelivo".home =
    { inputs, pkgs, ... }:
    {
      home.packages = [
        (import inputs.so1ve { inherit pkgs; }).kelivo
      ];
    };
}
