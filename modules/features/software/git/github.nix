{
  ray.features."software/git/github" = {
    requires.allOf = [
      "software/git"
      "software/ssh"
      "security/agenix"
    ];

    home =
      _:
      {
        config,
        inputs,
        user,
        ...
      }:
      let
        githubKey = config.age.secrets.ssh-github.path;
        githubPublicKey = builtins.readFile "${inputs.self}/keys/ssh-github.pub";
        allowedSignersFile = "${config.xdg.configHome}/git/allowed_signers";
      in
      {
        age.secrets.ssh-github = {
          file = "${inputs.self}/secrets/ssh-github.age";
          path = "${config.home.homeDirectory}/.ssh/ssh-github";
        };

        programs = {
          gh = {
            enable = true;
            settings.git_protocol = "ssh";
          };

          git = {
            signing = {
              key = githubPublicKey;
              format = "ssh";
              signByDefault = true;
            };

            settings.gpg.ssh.allowedSignersFile = allowedSignersFile;
          };

          ssh = {
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
