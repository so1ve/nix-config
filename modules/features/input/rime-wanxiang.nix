let
  wanxiang = import ../../../lib/mk-rime.nix {
    schema = "wanxiang";
    suggestedDefault = "wanxiang_suggested_default";
    languageModel = "wanxiang-lts-zh-hans.gram";

    dataPackage =
      pkgs:
      pkgs.so1ve.rime-wanxiang.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          for schema in wanxiang.schema.yaml wanxiang_english.schema.yaml; do
            substituteInPlace "$schema" \
              --replace-fail \
              '    - {when: always, accept: Shift+space, select: .next}  #下一个方案' \
              ""
          done

          substituteInPlace wanxiang.schema.yaml \
            --replace-fail '    Left: left_by_char_no_loop' '    Left: left_by_syllable_no_loop' \
            --replace-fail '    Right: right_by_char_no_loop' '    Right: right_by_syllable_no_loop'
        '';
      });
  };
in
{
  ray.features."input/rime-wanxiang" = {
    inherit (wanxiang) nixos;

    home = settings: {
      imports = [ (wanxiang.home settings) ];

      # Let the client preedit follow Rime's caret instead of pinning it.
      xdg.configFile."fcitx5/conf/rime.conf".text = ''
        PreeditCursorPositionAtBeginning=False
      '';
    };
  };
}
