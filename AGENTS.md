# AGENTS.md

## Repo status

Fresh scaffold for SQL learning notes/exercises. No source code, build, test, lint, or CI exists yet.
Do not invent commands — when you add tooling, document the exact commands here and in `README.md`.

## Formatting (enforced by config, easy to get wrong)

- Indent with **tabs** (width 4), LF line endings, UTF-8, trailing newline — every file type
  (`.editorconfig`, `.gitattributes` forces `eol=lf` globally).
- `.clang-format` targets **C#** with `UseTab: Always` and `ColumnLimit: 0` (never reflows lines).
  Run `clang-format` on any C/C++/C# you add.

## `.gitignore` gotchas

It is a large combined ignore file (Vim, VS, C/C++, CMake, Node, Python). Notable silent traps:

- Root `Makefile`, `compile_commands.json`, `CMakeCache.txt`, `CMakeFiles/` are ignored —
  a hand-written Makefile will be untracked without warning (`git add -f` or edit `.gitignore`).
- Also ignored: `bin/`, `obj/`, `*.log`, `node_modules/`, `__pycache__/`.

## Conventions

- Commits use short conventional prefixes: `chore:`, `doc:` (see history). Branch: `master`.
- Record notable changes in `CHANGELOG.md` under the existing empty `[Unreleased]` subsections
  (Keep a Changelog style); pending work goes in `TODO.md`.
- License: MIT.
