const { execFileSync } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const { parseArgs } = require("node:util");

const MODULE_ROOT = "__MODULE_ROOT__";
const GIT = "__GIT__";
const DIRENV = "__DIRENV__";
const DEFAULT_PROFILES = ["config"];
const PROFILES = {
  config: ["JSON, YAML, TOML and web document tooling, enabled by default", []],
  container: [
    "Dockerfile and Compose tooling",
    [
      "Dockerfile",
      "Dockerfile.*",
      "Containerfile",
      "Containerfile.*",
      "compose.yaml",
      "compose.yml",
      "docker-compose.yaml",
      "docker-compose.yml",
    ],
  ],
  frontend: [
    "Node.js, Bun, Deno, Corepack and frontend tooling",
    ["package.json"],
  ],
  go: ["Go, Delve, Task and editor tooling", ["go.mod", "go.work"]],
  haskell: [
    "GHC, Cabal, Stack, HLS, Fourmolu and HLint",
    [
      "*.cabal",
      "*.hs",
      "*.lhs",
      "cabal.project",
      "hie.yaml",
      "package.yaml",
      "stack.yaml",
    ],
  ],
  koka: ["Koka compiler and language server", ["*.kk", "*.kki"]],
  lean: [
    "Lean 4 via Elan, Lake and lean.nvim",
    ["lean-toolchain", "lakefile.lean", "lakefile.toml", "*.lean"],
  ],
  rust: [
    "rust-overlay, native build dependencies and editor tooling",
    ["Cargo.toml", "rust-toolchain", "rust-toolchain.toml"],
  ],
  zig: ["Zig and ZLS", ["build.zig", "build.zig.zon"]],
  python: [
    "Python, uv and editor tooling",
    ["pyproject.toml", "uv.lock", "requirements.txt"],
  ],
  cpp: [
    "GCC, Clang tools, CMake, Ninja, ccache and GDB",
    ["CMakeLists.txt", "meson.build", "Makefile", "*.c", "*.cc", "*.cpp"],
  ],
  lua: [
    "Lua, LuaRocks and editor tooling",
    [".luarc.json", "init.lua", "stylua.toml"],
  ],
  nix: [
    "nixd, nixfmt, deadnix and statix",
    ["flake.nix", "default.nix", "shell.nix"],
  ],
  shell: ["Shell language servers, ShellCheck and shfmt", ["*.sh", "*.fish"]],
  latex: ["TexLab and latexindent", ["*.tex", "*.bib"]],
  typst: ["Typst, Tinymist and Typstyle", ["*.typ"]],
};
const LOCAL_EXCLUDES = [
  "/devenv.local.nix",
  "/.devenv/",
  "/.devenv.flake.nix",
  "/.direnv/",
];
const GENERATED_EXCLUDES = [
  "/devenv.nix",
  "/devenv.yaml",
  "/devenv.lock",
];
const ENVRC_EXCLUDES = ["/.envrc"];

function detectProfiles(root) {
  return Object.entries(PROFILES)
    .filter(([, [, patterns]]) =>
      patterns.some((pattern) =>
        fs
          .globSync(pattern, { cwd: root })
          .some((file) => fs.statSync(path.join(root, file)).isFile()),
      ),
    )
    .map(([name]) => name);
}

function gitRoot() {
  return execFileSync(GIT, ["rev-parse", "--show-toplevel"], {
    encoding: "utf8",
  }).trim();
}

function updateGitExcludes(root, generatedExcludes, tracked) {
  const exclude = execFileSync(
    GIT,
    ["rev-parse", "--path-format=absolute", "--git-path", "info/exclude"],
    { cwd: root, encoding: "utf8" },
  ).trim();
  const currentExcludes = fs.existsSync(exclude)
    ? fs.readFileSync(exclude, "utf8").split("\n").filter(Boolean)
    : [];
  let excludes = [...new Set([...currentExcludes, ...LOCAL_EXCLUDES])];
  excludes = tracked
    ? excludes.filter((line) => !generatedExcludes.includes(line))
    : [...new Set([...excludes, ...generatedExcludes])];
  fs.mkdirSync(path.dirname(exclude), { recursive: true });
  fs.writeFileSync(exclude, `${excludes.join("\n")}\n`);
}

function init(requestedProfiles, tracked) {
  const unknown = requestedProfiles.find(
    (profile) => !Object.hasOwn(PROFILES, profile),
  );
  if (unknown) {
    console.error(`Unknown profile: ${unknown}`);
    process.exit(1);
  }

  const root = gitRoot();
  const detectedProfiles = requestedProfiles.length
    ? requestedProfiles
    : detectProfiles(root);
  const profiles = [...new Set([...DEFAULT_PROFILES, ...detectedProfiles])];

  const imports = profiles
    .map((profile) => `    ${MODULE_ROOT}/profiles/${profile}.nix`)
    .join("\n");
  const devenvNix = path.join(root, "devenv.nix");
  fs.writeFileSync(
    devenvNix,
    `{ lib, ... }:

{
  imports = [
${imports}
  ]
  ++ lib.optional (builtins.pathExists ./devenv.local.nix) ./devenv.local.nix;
}
`,
  );

  const extraInputs = [];

  if (profiles.includes("rust")) {
    extraInputs.push(`  rust-overlay:
    url: github:oxalica/rust-overlay
    inputs:
      nixpkgs:
        follows: nixpkgs`);
  }

  if (profiles.includes("frontend")) {
    extraInputs.push(`  js-toolchain-overlay:
    url: github:so1ve/js-toolchain-overlay
    inputs:
      nixpkgs:
        follows: nixpkgs`);
  }

  const devenvYaml = path.join(root, "devenv.yaml");
  fs.writeFileSync(
    devenvYaml,
    `inputs:
  nixpkgs:
    url: github:cachix/devenv-nixpkgs/rolling
${extraInputs.join("\n")}`,
  );

  const envrc = path.join(root, ".envrc");
  if (!fs.existsSync(envrc)) {
    writeEnvrc(root);
  }
  updateGitExcludes(
    root,
    [...GENERATED_EXCLUDES, ...ENVRC_EXCLUDES],
    tracked,
  );
  allowDirenv(root);
  console.log(`Configured ${root} with profiles: ${profiles.join(" ")}`);
}

function writeEnvrc(root) {
  const envrc = path.join(root, ".envrc");
  fs.writeFileSync(
    envrc,
    `#!/usr/bin/env bash

eval "$(devenv direnvrc)"
use devenv --quiet
`,
  );
  return envrc;
}

function allowDirenv(root) {
  execFileSync(DIRENV, ["allow", "."], {
    cwd: root,
    stdio: "inherit",
  });
}

function generateEnvrc(tracked) {
  const root = gitRoot();
  const envrc = writeEnvrc(root);
  updateGitExcludes(root, ENVRC_EXCLUDES, tracked);
  allowDirenv(root);
  console.log(`Generated and allowed ${envrc}`);
}

function list() {
  const width = Math.max(...Object.keys(PROFILES).map((name) => name.length));
  console.log(
    Object.entries(PROFILES)
      .map(([name, [description]]) => `${name.padEnd(width)}  ${description}`)
      .join("\n"),
  );
}

const {
  values: { tracked = false },
  positionals: [command, ...profiles],
} = parseArgs({
  options: { tracked: { type: "boolean", short: "t" } },
  allowPositionals: true,
});

switch (command) {
  case "list":
    list();
    break;
  case "init":
    init(profiles, tracked);
    break;
  case "envrc":
    generateEnvrc(tracked);
    break;
  default:
    console.error(
      `Usage: dev-env <command> [options] [profiles...]

Commands:
    list   List available profiles
    init   Initialize the development environment
    envrc  Generate and allow .envrc`,
    );
    process.exit(1);
}
