#!/usr/bin/env node
/**
 * Validate a Cubism runtime model folder before loading it in the playground.
 *
 * Usage:
 *   npm run check-model -- models/example
 *   npm run check-model -- /absolute/path/to/MyChar
 */
import { readdir, readFile, stat } from "node:fs/promises";
import { basename, join, resolve } from "node:path";

const REQUIRED_SUFFIXES = [".moc3", ".model3.json"];

/**
 * @param {unknown} value
 * @returns {value is Record<string, unknown>}
 */
function isObject(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/**
 * @param {string} dir
 */
async function listFilesRecursive(dir) {
  /** @type {string[]} */
  const out = [];
  const entries = await readdir(dir, { withFileTypes: true });
  for (const entry of entries) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      out.push(...(await listFilesRecursive(full)));
    } else {
      out.push(full);
    }
  }
  return out;
}

/**
 * @param {string} modelDir
 */
async function checkModel(modelDir) {
  const abs = resolve(modelDir);
  const info = await stat(abs);
  if (!info.isDirectory()) {
    throw new Error(`Not a directory: ${abs}`);
  }

  const files = await listFilesRecursive(abs);
  const relative = files.map((f) => f.slice(abs.length + 1).replaceAll("\\", "/"));

  /** @type {string[]} */
  const problems = [];
  /** @type {string[]} */
  const notes = [];

  const model3 = relative.filter((f) => f.endsWith(".model3.json"));
  const moc3 = relative.filter((f) => f.endsWith(".moc3"));
  const textures = relative.filter((f) => /\.png$/i.test(f));
  const motions = relative.filter((f) => f.endsWith(".motion3.json"));
  const expressions = relative.filter((f) => f.endsWith(".exp3.json"));
  const physics = relative.filter((f) => f.endsWith(".physics3.json"));
  const pose = relative.filter((f) => f.endsWith(".pose3.json"));

  if (model3.length === 0) problems.push("Missing *.model3.json");
  if (moc3.length === 0) problems.push("Missing *.moc3");
  if (textures.length === 0) problems.push("Missing texture PNG files");

  for (const suffix of REQUIRED_SUFFIXES) {
    if (!relative.some((f) => f.endsWith(suffix))) {
      // already covered above; keep for clarity
    }
  }

  if (model3.length > 1) {
    notes.push(`Multiple model3.json files found (${model3.length}). Prefer one root entry.`);
  }

  for (const settingsPath of model3) {
    const raw = await readFile(join(abs, settingsPath), "utf8");
    /** @type {unknown} */
    let json;
    try {
      json = JSON.parse(raw);
    } catch {
      problems.push(`${settingsPath}: invalid JSON`);
      continue;
    }
    if (!isObject(json)) {
      problems.push(`${settingsPath}: root must be an object`);
      continue;
    }

    const fileRefs = json.FileReferences;
    if (!isObject(fileRefs)) {
      problems.push(`${settingsPath}: missing FileReferences`);
      continue;
    }

    if (typeof fileRefs.Moc !== "string") {
      problems.push(`${settingsPath}: FileReferences.Moc must be a string`);
    } else {
      const mocRel = join(dirnameOf(settingsPath), fileRefs.Moc).replaceAll("\\", "/");
      if (!relative.includes(normalizeRel(mocRel))) {
        problems.push(`${settingsPath}: moc not found at ${mocRel}`);
      }
    }

    if (!Array.isArray(fileRefs.Textures) || fileRefs.Textures.length === 0) {
      problems.push(`${settingsPath}: FileReferences.Textures must be a non-empty array`);
    } else {
      for (const tex of fileRefs.Textures) {
        if (typeof tex !== "string") {
          problems.push(`${settingsPath}: texture entry must be string`);
          continue;
        }
        const texRel = normalizeRel(join(dirnameOf(settingsPath), tex));
        if (!relative.includes(texRel)) {
          problems.push(`${settingsPath}: texture not found at ${texRel}`);
        }
      }
    }
  }

  console.log(`\nModel check: ${basename(abs)}`);
  console.log(`Path: ${abs}`);
  console.log(`Files: ${relative.length}`);
  console.log(`  model3.json : ${model3.length}`);
  console.log(`  moc3        : ${moc3.length}`);
  console.log(`  textures    : ${textures.length}`);
  console.log(`  motions     : ${motions.length}`);
  console.log(`  expressions : ${expressions.length}`);
  console.log(`  physics     : ${physics.length}`);
  console.log(`  pose        : ${pose.length}`);

  if (notes.length) {
    console.log("\nNotes:");
    for (const n of notes) console.log(`  - ${n}`);
  }

  if (problems.length) {
    console.log("\nProblems:");
    for (const p of problems) console.log(`  x ${p}`);
    process.exitCode = 1;
    return;
  }

  console.log("\nOK: runtime package looks loadable.");
  if (model3[0]) {
    console.log(`Suggested playground path: /models/${basename(abs)}/${model3[0]}`);
  }
}

/**
 * @param {string} p
 */
function dirnameOf(p) {
  const i = p.lastIndexOf("/");
  return i === -1 ? "" : p.slice(0, i);
}

/**
 * @param {string} p
 */
function normalizeRel(p) {
  return p.replaceAll("\\", "/").replace(/^\.\//, "").replace(/\/+/g, "/");
}

const target = process.argv[2];
if (!target) {
  console.error("Usage: npm run check-model -- <model-directory>");
  process.exit(1);
}

checkModel(target).catch((err) => {
  console.error(err);
  process.exit(1);
});
