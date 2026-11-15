{
  lib,
  runCommand,
  python3,
  uv,
}:

runCommand "hermes-personal-tools"
  {
    src = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions [
        ./pyproject.toml
        ./uv.lock
        ./README.md
        (lib.fileset.fileFilter (file: file.hasExt "py") ./src)
        (lib.fileset.fileFilter (file: file.hasExt "py") ./scripts)
        ./hooks/proactive-chat/HOOK.yaml
        ./hooks/proactive-chat/handler.py
        ./skills
      ];
    };
    nativeBuildInputs = [
      (python3.withPackages (ps: [ ps.hatchling ]))
      uv
    ];
  }
  ''
    cd "$src"
    mkdir -p "$out"
    python -m hatchling build -t wheel -d "$out"
    uv export --offline --no-cache --frozen --no-dev --no-emit-project --no-header > "$out/requirements.txt"
    wheel=$(basename "$out"/*.whl)
    hash=$(sha256sum "$out/$wheel" | cut -d ' ' -f 1)
    printf '\n./%s --hash=sha256:%s\n' "$wheel" "$hash" >> "$out/requirements.txt"
    cp -r hooks scripts skills "$out/"
  ''
