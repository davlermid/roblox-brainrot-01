// main.ts - STEAL A SNACKROT entry point
// Copies game.rbxl, src/, screenshots/, PLAY.json to /output and writes dossier.json
// Deterministic build: same bytes on repeated runs.

import { copyFileSync, cpSync, existsSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDossier } from './vendor/makefun-roblox.ts';

const here = fileURLToPath(new URL('.', import.meta.url));
const out = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

/** cpSync's filter: leave out every file and directory whose name starts with a dot (.gitkeep, .DS_Store, .git). */
const notDotted = (path: string): boolean => !basename(path).startsWith('.');

// Ensure clean output directory
if (existsSync(out)) {
    rmSync(out, { recursive: true, force: true });
}
mkdirSync(out, { recursive: true });

// Copy game.rbxl
copyFileSync(join(here, 'game.rbxl'), join(out, 'game.rbxl'));

// Copy PLAY.json
copyFileSync(join(here, 'PLAY.json'), join(out, 'PLAY.json'));

// Copy src/ (all .luau files)
cpSync(join(here, 'src'), join(out, 'src'), { recursive: true, filter: notDotted });

// Copy screenshots/
mkdirSync(join(out, 'screenshots'), { recursive: true });
if (existsSync(join(here, 'screenshots'))) {
    cpSync(join(here, 'screenshots'), join(out, 'screenshots'), { recursive: true, filter: notDotted });
}

// Copy default.project.json
copyFileSync(join(here, 'default.project.json'), join(out, 'default.project.json'));

// Copy TOUR.json
if (existsSync(join(here, 'TOUR.json'))) {
    copyFileSync(join(here, 'TOUR.json'), join(out, 'TOUR.json'));
}

// Build dossier with caps from gate.json reference
writeFileSync(
    join(out, 'dossier.json'),
    buildDossier(out, {
        text_max_bytes: 65536,
        screenshots: { max: 4, max_bytes: 262144 },
        max_instances: 500000,
        scripts_max_source_bytes: 8388608,
        scripts_max_path_chars: 1048576,
    })
);

console.log('Build complete. Output written to:', out);