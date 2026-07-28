{ pkgs, ... }:

{
  imports = [ ./config.nix ];

  packages = with pkgs; [
    docker-compose-language-service
    dockerfile-language-server
  ];
}
