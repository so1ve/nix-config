{
  ray.features."hardware/ryzen-boost" = {
    nixos =
      _:
      { pkgs, ... }:
      let
        ryzenBoostApply = pkgs.writeShellApplication {
          name = "ryzen-boost-apply";
          runtimeInputs = with pkgs; [
            coreutils
            ryzenadj
          ];
          text = builtins.readFile ./ryzen-boost/apply.sh;
        };

        ryzenBoostBin = pkgs.writeShellApplication {
          name = "ryzen-boost";
          runtimeInputs = with pkgs; [
            coreutils
            gawk
            gnugrep
            gnused
            systemd
          ];
          text = builtins.readFile ./ryzen-boost/cli.sh;
        };

        ryzenBoostCli = pkgs.runCommand "ryzen-boost" { } ''
          mkdir -p \
            "$out/bin" \
            "$out/share/fish/vendor_completions.d" \
            "$out/share/bash-completion/completions" \
            "$out/share/zsh/site-functions"

          ln -s "${ryzenBoostBin}/bin/ryzen-boost" "$out/bin/ryzen-boost"

          cat > "$out/share/fish/vendor_completions.d/ryzen-boost.fish" <<'EOF'
          complete -c ryzen-boost -f
          complete -c ryzen-boost -n "__fish_use_subcommand" -a "on" -d "Enable sustained 42W/48W boost on AC"
          complete -c ryzen-boost -n "__fish_use_subcommand" -a "off" -d "Disable boost and restore stock 29W"
          complete -c ryzen-boost -n "__fish_use_subcommand" -a "status" -d "Show boost service, power, clocks, and temperature"
          EOF

          cat > "$out/share/bash-completion/completions/ryzen-boost" <<'EOF'
          _ryzen_boost() {
            local cur="''${COMP_WORDS[COMP_CWORD]}"
            if [ "$COMP_CWORD" -eq 1 ]; then
              COMPREPLY=( $(compgen -W "on off status" -- "$cur") )
            fi
          }
          complete -F _ryzen_boost ryzen-boost
          EOF

          cat > "$out/share/zsh/site-functions/_ryzen-boost" <<'EOF'
          #compdef ryzen-boost
          _arguments '1:action:(
            "on:Enable sustained 42W/48W boost on AC"
            "off:Disable boost and restore stock 29W"
            "status:Show boost service, power, clocks, and temperature"
          )'
          EOF
        '';
      in
      {
        environment.systemPackages = with pkgs; [
          ryzenadj
          ryzenBoostCli
        ];

        security.polkit.extraConfig = ''
          polkit.addRule(function(action, subject) {
            if (
              action.id == "org.freedesktop.systemd1.manage-units" &&
              action.lookup("unit") == "ryzen-boost.service" &&
              subject.isInGroup("wheel")
            ) {
              return polkit.Result.YES;
            }
          });
        '';

        systemd.services.ryzen-boost = {
          description = "Ryzen APU sustained power boost on AC (keepalive against EC reset)";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "simple";
            ExecStart = "${ryzenBoostApply}/bin/ryzen-boost-apply";
            ExecStopPost = "${ryzenBoostApply}/bin/ryzen-boost-apply reset";
            Restart = "on-failure";
            RestartSec = "5s";
          };
        };

        programs.gamemode.settings.custom.start =
          "${pkgs.systemd}/bin/systemctl --no-block start ryzen-boost.service";
      };
  };
}
