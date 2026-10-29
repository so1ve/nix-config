# Ray's nix config

Public NixOS and Home Manager features, packages, and dotfiles. Real host definitions,
network addresses, SSH authorization, and encrypted credentials are maintained in a
separate private configuration.

Features configure services and reference runtime secrets such as
`config.age.secrets.cloudflared-env.path`. Each private host declares encrypted files
such as `age.secrets.cloudflared-env.file` in its `_secrets.nix` module. Private feature
extensions can add personal behavior to the same `nixos` or `home` module; both
definitions merge through the existing feature system.

Use `just write-flake` after changing flake inputs. More command shortcuts available
in `just --list`.

## LICENSE

[Unlicense](LICENSE). Made with ♥️ by [Ray](https://github.com/so1ve)
