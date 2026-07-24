{
  ray.features."software/git" = {
    home =
      {
        config,
        registry,
        username,
        ...
      }:
      let
        user = registry.users.${username};
        githubKey = config.age.secrets.github-ssh.path;
        githubPublicKey = builtins.readFile ../../../keys/ray-github.pub;
        allowedSignersFile = "${config.xdg.configHome}/git/allowed_signers";
      in
      {
        programs = {
          gh = {
            enable = true;
            settings.git_protocol = "ssh";
          };

          git = {
            enable = true;

            signing = {
              key = githubPublicKey;
              format = "ssh";
              signByDefault = true;
            };

            settings = {
              user = {
                name = user.gitName;
                email = user.gitEmail;
              };

              gpg.ssh.allowedSignersFile = allowedSignersFile;
              merge.conflictStyle = "zdiff3";
              status.showUntrackedFiles = "all";
            };
          };

          ssh = {
            enable = true;
            enableDefaultConfig = false;

            settings."github.com" = {
              HostName = "ssh.github.com";
              Port = 443;
              User = "git";
              IdentityFile = githubKey;
              IdentitiesOnly = true;
              AddKeysToAgent = "yes";
            };
          };
        };

        xdg.configFile."git/allowed_signers".text = "${user.gitEmail} ${githubPublicKey}";
      };
  };
}
