{
  ray.features."input/rime-wanxiang" = import ../../../lib/mk-rime.nix {
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
        '';
      });
  };
}
