{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  nur = import inputs.so1ve { inherit pkgs; };
in
{
  languages.java = {
    enable = true;
    jdk.package = lib.mkDefault pkgs.jdk17;
  };

  packages = [
    nur.kotlin-lsp
    nur.gradle-language-server
  ];
}
