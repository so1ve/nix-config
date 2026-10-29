{ config, lib, ... }:

let
  serverHosts = lib.filterAttrs (_: host: host.isServer) config.ray.hosts.nixos;
in
{
  ray.features."software/ssh".home = _: {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      # Add declared servers to SSH configuration and hostname completion.
      settings = lib.mapAttrs (_: host: {
        HostName = host.hostname;
        User = host.username;
      }) serverHosts;
    };
  };

  ray.features."software/ssh/admin" = {
    requires.allOf = [
      "software/ssh"
      "security/agenix"
    ];

    home =
      _:
      {
        config,
        hostname,
        ...
      }:
      let
        keyName = "ssh-admin-${hostname}";
      in
      {
        age.secrets.${keyName}.path = "${config.home.homeDirectory}/.ssh/${keyName}";

        programs.ssh.settings."* !github.com !ssh.github.com" = {
          IdentityFile = config.age.secrets.${keyName}.path;
          IdentitiesOnly = true;
        };
      };
  };
}
