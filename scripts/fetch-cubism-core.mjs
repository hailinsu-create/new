#!/usr/bin/env node
/**
 * Download Live2D Cubism Core for local research demos.
 * Cubism Core is proprietary. Do not redistribute the downloaded file.
 * Production apps should obtain Core from the official Cubism SDK for Web package.
 */
import { createWriteStream } from "node:fs";
import { mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { pipeline } from "node:stream/promises";

const CORE_URL =
  "https://cubism.live2d.com/sdk-web/cubismcore/live2dcubismcore.min.js";
const OUT = resolve(
  dirname(fileURLToPath(import.meta.url)),
  "../public/live2dcubismcore.min.js",
);

async function main() {
  await mkdir(dirname(OUT), { recursive: true });
  console.log(`Fetching Cubism Core from ${CORE_URL}`);
  const res = await fetch(CORE_URL);
  if (!res.ok || !res.body) {
    throw new Error(`Failed to download Cubism Core: HTTP ${res.status}`);
  }
  await pipeline(res.body, createWriteStream(OUT));
  console.log(`Wrote ${OUT}`);
  console.log(
    "Reminder: Cubism Core is proprietary. Keep it out of public redistribution.",
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
