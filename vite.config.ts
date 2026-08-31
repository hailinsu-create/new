import fs from "node:fs";
import path from "node:path";
import { defineConfig, type Plugin } from "vite";

function serveDocs(): Plugin {
  const docsRoot = path.resolve("docs");

  return {
    name: "serve-docs",
    configureServer(server) {
      server.middlewares.use((req, res, next) => {
        if (!req.url?.startsWith("/docs/")) {
          next();
          return;
        }
        const rel = decodeURIComponent(req.url.slice("/docs/".length).split("?")[0] ?? "");
        const file = path.resolve(docsRoot, rel);
        if (!file.startsWith(docsRoot) || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
          next();
          return;
        }
        res.setHeader("Content-Type", "text/markdown; charset=utf-8");
        fs.createReadStream(file).pipe(res);
      });
    },
    closeBundle() {
      const outDocs = path.resolve("dist/docs");
      fs.mkdirSync(outDocs, { recursive: true });
      for (const name of fs.readdirSync(docsRoot)) {
        if (!name.endsWith(".md")) continue;
        fs.copyFileSync(path.join(docsRoot, name), path.join(outDocs, name));
      }

      const charSrc = path.resolve("characters/moxi");
      const charOut = path.resolve("dist/characters/moxi");
      fs.mkdirSync(charOut, { recursive: true });
      for (const name of ["CHARACTER.md"]) {
        const src = path.join(charSrc, name);
        if (fs.existsSync(src)) fs.copyFileSync(src, path.join(charOut, name));
      }
      const checklist = path.join(charSrc, "cubism/BINDING_CHECKLIST.md");
      if (fs.existsSync(checklist)) {
        fs.mkdirSync(path.join(charOut, "cubism"), { recursive: true });
        fs.copyFileSync(checklist, path.join(charOut, "cubism/BINDING_CHECKLIST.md"));
      }
    },
  };
}

export default defineConfig({
  plugins: [serveDocs()],
  server: {
    host: "0.0.0.0",
    port: 5173,
    watch: {
      ignored: ["**/tools/cubism/wineprefix/**", "**/node_modules/**"]
    }
  },
  build: {
    target: "es2022",
  },
});
