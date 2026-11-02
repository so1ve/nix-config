import {
  rm,
  readdir,
  readFile,
  stat,
  unlink,
  writeFile,
} from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { gzipSync } from "node:zlib";
import { build } from "esbuild";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
process.chdir(root);
const assets = "../web/assets";
const aliases = {
  "@pierre/highlights/themes/loader": "./src/highlighter-stub.js",
  "@pierre/theming/themes": "./src/highlighter-stub.js",
  "shiki/core": "./src/highlighter-stub.js",
  "shiki/engine/javascript": "./src/highlighter-stub.js",
  "shiki/engine/oniguruma": "./src/highlighter-stub.js",
  "shiki/langs": "./src/highlighter-stub.js",
  "shiki/wasm": "./src/highlighter-stub.js",
};

async function filesBelow(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) files.push(...(await filesBelow(path)));
    else files.push(path);
  }
  return files;
}

await rm(assets, { recursive: true, force: true });
await build({
  absWorkingDir: root,
  entryPoints: ["src/review.jsx"],
  bundle: true,
  format: "esm",
  splitting: true,
  outdir: assets,
  entryNames: "review",
  chunkNames: "chunks/[name]-[hash]",
  assetNames: "fonts/[name]-[hash]",
  loader: { ".woff2": "file" },
  alias: aliases,
  jsx: "automatic",
  minify: true,
  target: "es2022",
  logLevel: "warning",
});

let originalBytes = 0;
let compressedBytes = 0;
for (const path of await filesBelow(assets)) {
  const details = await stat(path);
  originalBytes += details.size;
  if (!path.endsWith(".js") && !path.endsWith(".css")) continue;
  const data = await readFile(path);
  const compressed = gzipSync(data, { level: 9 });
  await writeFile(`${path}.gz`, compressed);
  await unlink(path);
  compressedBytes += compressed.length;
}

const saved = originalBytes - compressedBytes;
console.log(
  `Built ${(compressedBytes / 1024).toFixed(0)} KiB compressed ` +
    `(${(saved / 1024).toFixed(0)} KiB smaller than text assets).`,
);
