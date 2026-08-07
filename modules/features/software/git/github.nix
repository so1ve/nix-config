{
  ray.features."software/git/github" = {
    requires = [
      "software/git"
      "security/agenix"
    ];

    home =
      {
        config,
        inputs,
        user,
        ...
      }:
      let
        githubKey = config.age.secrets.github-ssh.path;
        githubPublicKey = builtins.readFile "${inputs.self}/keys/ray-github.pub";
        allowedSignersFile = "${config.xdg.configHome}/git/allowed_signers";
      in
      {
        age.secrets.github-ssh = {
          file = "${inputs.self}/secrets/github-ssh.age";
          path = "${config.home.homeDirectory}/.ssh/id_ed25519_github";
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
