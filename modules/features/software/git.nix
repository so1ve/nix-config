{
  ray.features."software/git" = {
    requires = [ "security/agenix" ];

    home =
      {
        config,
        user,
        ...
      }:
      let
        githubKey = config.age.secrets.github-ssh.path;
        githubPublicKey = builtins.readFile ../../../keys/ray-github.pub;
        allowedSignersFile = "${config.xdg.configHome}/git/allowed_signers";
      in
      {
        age.secrets.github-ssh = {
          file = ../../../secrets/github-ssh.age;
          path = "${config.home.homeDirectory}/.ssh/id_ed25519_github";
        };

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
              core = {
                autocrlf = false;
                eol = "lf";
              };

              init.defaultBranch = "main";
              merge.conflictStyle = "zdiff3";
              pull.rebase = true;
              push.autoSetupRemote = true;
              status.showUntrackedFiles = "all";

              user = {
                name = user.gitName;
                email = user.gitEmail;
              };

              gpg.ssh.allowedSignersFile = allowedSignersFile;
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
