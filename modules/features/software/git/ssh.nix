{ lib, ... }:

{
  ray.features."software/git/ssh" = {
    requires.allOf = [
      "software/git"
      "software/ssh"
      "security/agenix"
    ];

    options = {
      hosts = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              HostName = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
              };
              Port = lib.mkOption {
                type = lib.types.nullOr lib.types.port;
                default = null;
              };
            };
          }
        );
        default = { };
        description = "Additional Git SSH hosts, merged over the built-in GitHub hosts.";
      };
    };

    home =
      settings:
      {
        config,
        user,
        ...
      }:
      let
        gitKey = config.age.secrets.ssh-git.path;
        gitPublicKey = builtins.readFile config.home.file.".ssh/ssh-git.pub".source;
        allowedSignersFile = "${config.xdg.configHome}/git/allowed_signers";
        defaultHosts = {
          "github.com ssh.github.com" = {
            HostName = "ssh.github.com";
            Port = 443;
          };
        };
        gitHosts = defaultHosts // settings.hosts;
        mkGitHost =
          host:
          {
            User = "git";
            IdentityFile = gitKey;
            IdentitiesOnly = true;
          }
          // lib.filterAttrs (_: value: value != null) host;
      in
      {
        age.secrets.ssh-git.path = "${config.home.homeDirectory}/.ssh/ssh-git";

        programs = {
          git = {
            signing = {
              key = gitKey;
              format = "ssh";
              signByDefault = true;
            };

            settings.gpg.ssh.allowedSignersFile = allowedSignersFile;
          };

          ssh.settings = lib.mapAttrs (_: mkGitHost) gitHosts;
        };

        xdg.configFile."git/allowed_signers".text = "${user.gitEmail} ${gitPublicKey}";
      };
  };
}
