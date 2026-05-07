#!/usr/bin/env node
// Idempotent JSON-merge for OMNI_SKILLS hooks. Mirrors caveman pattern.
// Reads OMNI_SETTINGS, OMNI_SKILLS_DIR, OMNI_HOOK_TAG from env.
// Adds SessionStart hook that echoes loaded skills, only once.
const fs = require('fs');
const path = require('path');

const settingsPath = process.env.OMNI_SETTINGS;
const skillsDir = process.env.OMNI_SKILLS_DIR;
const tag = process.env.OMNI_HOOK_TAG || 'omni-skills';

if (!settingsPath || !skillsDir) {
  console.error('merge-settings.js: missing OMNI_SETTINGS or OMNI_SKILLS_DIR env');
  process.exit(2);
}

let raw = '{}';
try {
  raw = fs.readFileSync(settingsPath, 'utf8');
} catch (e) {
  if (e.code !== 'ENOENT') throw e;
}

let settings;
try {
  settings = raw.trim() === '' ? {} : JSON.parse(raw);
} catch (e) {
  console.error('settings.json: parse error — refusing to overwrite. ' + e.message);
  process.exit(3);
}

if (!settings.hooks) settings.hooks = {};
if (!Array.isArray(settings.hooks.SessionStart)) settings.hooks.SessionStart = [];

const already = settings.hooks.SessionStart.some(e =>
  Array.isArray(e.hooks) && e.hooks.some(h =>
    typeof h.command === 'string' && h.command.includes(tag)
  )
);

if (!already) {
  // Cross-platform announcement: echo skill names. Tag in command for idempotency check.
  const skillsList = fs.readdirSync(skillsDir, { withFileTypes: true })
    .filter(d => d.isDirectory())
    .map(d => d.name)
    .join(',');
  const cmd = process.platform === 'win32'
    ? `cmd.exe /c echo [${tag}] skills loaded: ${skillsList}`
    : `echo "[${tag}] skills loaded: ${skillsList}"`;
  settings.hooks.SessionStart.push({
    hooks: [{
      type: 'command',
      command: cmd,
      timeout: 5,
      statusMessage: `Loading ${tag}...`
    }]
  });
}

fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + '\n');
console.log(already ? `  ${tag} hook already present` : `  ${tag} hook wired`);
