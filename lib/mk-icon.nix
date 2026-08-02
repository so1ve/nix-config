{ lib }:

name:

let
  icon = ../assets/icons + "/${name}";
in
assert lib.assertMsg (builtins.pathExists icon) "mkIcon: icon '${name}' does not exist";
icon
