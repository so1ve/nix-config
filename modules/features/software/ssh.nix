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
        inputs,
        ...
      }:
      let
        keyName = "ssh-admin-${hostname}";
      in
      {
        age.secrets.${keyName} = {
          file = "${inputs.self}/secrets/${keyName}.age";
          path = "${config.home.homeDirectory}/.ssh/${keyName}";
        };

        home.file.".ssh/${keyName}.pub".source = "${inputs.self}/keys/${keyName}.pub";

        programs.ssh.settings."* !github.com !ssh.github.com" = {
          IdentityFile = config.age.secrets.${keyName}.path;
          IdentitiesOnly = true;
        };
      };
  };
}
