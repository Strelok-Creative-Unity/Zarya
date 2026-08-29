#!/usr/bin/env node
import archiver from "archiver";
import { createWriteStream, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const EXTRA_FILES = ["LICENSE", "TNE_LICENSE.md", "THIRD_PARTY_NOTICES.md"];

const dir = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(dir, "..");
const { version } = JSON.parse(readFileSync(path.join(dir, "package.json")));

const zip = path.join(root, `Zarya-${version}.zip`);

const archive = archiver("zip");
archive.pipe(createWriteStream(zip));
archive.directory(path.join(root, "shaders"), "shaders");
for (const f of EXTRA_FILES) {
  archive.file(path.join(root, f), { name: f });
}
await archive.finalize();

console.log(zip);
