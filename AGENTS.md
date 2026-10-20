# ForerunnerFace
Garmin Forerunner watch faces (Connect IQ, Monkey C): one folder per face (manifest.xml, monkey.jungle, resources/,
CHANGELOG.md, store/); FaceCore/ is the shared code and tooling (read `FaceCore/AGENTS.md` before changing any face).
Personal rules for all projects: ~/.agents/AGENTS.md.

## Shared by Claude and Gemini/Antigravity
- **Instructions**: `AGENTS.md` here and in each face folder is the single source. `CLAUDE.md` and `GEMINI.md` next
  to it only import it; edit `AGENTS.md`, never the pointers. A new folder gets all three.
  Exception: `ApexFace/CLAUDE.md` is the real file (ApexFace is hands off), so Gemini reads it directly there.
- **Open work**: `TODO.md`. Confirmed features go in with their steps; done items are deleted.
- **Memory**: `.agents/memory/` (read `README.md` first, one fact per file). Save durable decisions, conventions and
  known issues there, not in a tool's private memory.
- **Skills**: `.agents/skills/<name>/SKILL.md` is the source; when a task matches a skill below,
  read its SKILL.md and follow it. Claude finds them through a
  stub in `.claude/skills/<name>/SKILL.md` with the same name and description; add one for every new skill.
  Current skills: `finish-face-change` (tests, changelog, store text and shots after a face change),
  `push-to-watch` (sideload a build over MTP, only on request).
- Never put secrets (keys, passwords, tokens) in any of these files.
