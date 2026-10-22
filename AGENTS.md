# AGENTS.md

## Repo status

Self-study SQL curriculum: 5 dense days that carry SQLite basics into enterprise T-SQL and end
with safe database access from C#.

- Day 1 and Day 2 are written; Day 3–5 are planned (`TODO.md` tracks progress).
- Target dialect is **SQL Server 2014**. Syntax that only exists in newer versions must be marked
  with ⚠️ in the lessons, because the company server is 2014.
- Practice environment: the company SQL Server 2014 Express instance `localhost\SQLEXPRESS`
  (primary), or the Docker SQL Server 2022 container in `curriculum/common/docker-compose.yml`
  (x86_64 only; on ARM64 a 4 KB-page kernel is required but not yet verified, see
  `curriculum/common/SETUP.md` §4).
- Offline T-SQL check (no database needed, .NET 8+ SDK). Run from the repo root:

  ```bash
  tools/check.sh                        # all .sql under curriculum/
  tools/check.sh curriculum/day01_select
  tools/check.sh path/to/file.sql --verbose
  tools/test.sh                         # self-tests of the checker
  ```

  `tools/check.sh` exits 1 when it finds a problem. It combines the ScriptDom
  `TSql120Parser` (2014 grammar), a DacFx `SqlServerVersion.Sql120` model built from
  `curriculum/common/seed.sql` (unresolved table/column references), and the rule list in
  `tools/sqlcheck/compat2014.txt` (2016+ functions the parser accepts, e.g. `STRING_AGG`).
  Known gaps: batches that use temp tables (`#t`) or `ALTER TABLE` skip the reference check.
- End-to-end validation is still manual: run the `.sql` files with `sqlcmd` against a live
  server and compare the `-- 預期：` values in `answers.sql`. There is no CI (the git remote is a
  local Gitea instance).
- Do not invent commands — when you add tooling, document the exact commands here and in `README.md`.

## Workflow

### 1. Before you start

- Read `README.md`, `curriculum/README.md`, `TODO.md`, and `CHANGELOG.md` to learn the current
  state and the conventions in use.
- Run `git status` first. If the working tree is dirty, find out where those changes came from
  before touching them — never discard or overwrite work you did not create.
- Plan multi-file work up front and decide the commit split (see §4) before editing.

### 2. Editing rules

- Tabs (width 4), LF line endings, UTF-8, trailing newline — every file type. See `## Formatting`.
- Run `clang-format` on any C/C++/C# you add.
- Lessons are Traditional Chinese prose; SQL is T-SQL and must stay SQL Server 2014 compatible.
  After editing any `.sql`, run `tools/check.sh` and fix what it reports (or mark the lesson line
  with ⚠️ if the newer syntax is intentional).
- Each day folder holds `lesson.md` (concepts), `exercises.sql` (practice), and
  `answers.sql` (answers + explanations) — keep that shape, and keep exercises and answers in sync.
- Keep `README.md`, `curriculum/README.md`, `TODO.md`, and `CHANGELOG.md` in sync with whatever
  content you change.

### 3. Commit rules

- **Every change gets committed.** Do not finish a task with a dirty working tree.
- One commit = one logically complete change that can be reverted on its own. Never mix unrelated
  files into the same commit.
- Message format: `<type>: <summary>`, where type is one of `feat:`, `doc:`, `chore:`, `fix:`,
  `refactor:`, `test:`. Summaries follow the existing history: short, Chinese, no trailing period.
- After the summary, leave a blank line and a body that states **what changed** and **why it changed**:

```
doc: 新增 Day 3 課程 - 子查詢與 CTE

新增 curriculum/day03_subquery_dml/ 下的 lesson.md、exercises.sql 與 answers.sql，
涵蓋子查詢、CTE 以及 INSERT/UPDATE/DELETE 的安全寫法。

Why: 5 天路線圖的 Day 3 原本只有一個資料夾名，學員沒有教材可讀；補齊後
Day 1→3 的進度才連得起來，exercises.sql 也才有對應的參考答案。
```

- Do not amend or rebase commits that were already pushed (see §8).

### 4. Large changes → split into multiple commits

- Split when a change is too big to review, verify, or revert as one unit.
- Split along this order: content → support files → docs/index updates. Example (a new curriculum day):
  1. `doc: 新增 Day 3 課程內容` — `curriculum/day03_subquery_dml/lesson.md`
  2. `doc: 新增 Day 3 練習題與答案` — `exercises.sql`, `answers.sql`
  3. `doc: 更新 README 與 TODO 的 Day 3 進度` — `README.md`, `curriculum/README.md`, `TODO.md`, `CHANGELOG.md`
- Every commit must leave the repository in a usable state — no commit may break the docs, the
  links, or the lesson/exercise/answer pairing.
- `CHANGELOG.md` follows the same rule: record the entries for the change **in the same commit**
  as that change, not in one catch-all commit at the end.

### 5. `CHANGELOG.md` maintenance

- Keep a Changelog format; keep the existing `## [Unreleased]` section and its
  `Added` / `Changed` / `Fixed` / `Security` / `Removed` / `Deprecated` subsections.
- Entry format: ``- `path/to/file`：說明。`` — one bullet per user-visible change.
- Update it in the same commit as the change it describes.
- Never rewrite entries of an already released version; this repo currently only has `[Unreleased]`.

### 6. `TODO.md` maintenance

- Use `- [ ]` for pending work and `- [x]` for finished work.
- Every item states **what to do** and **what "done" looks like** (which file, which chapter,
  which verification step).
- Add an item when work is deferred, blocked, or needs on-site access; tick it off as soon as it is
  done; remove items that no longer matter.

### 7. Python: always use `uv`

- Never invoke bare `python`, `python3`, `pip`, `pip3`, `virtualenv`, or `poetry`.
- Run scripts with `uv run <script>`; ad-hoc dependencies with `uv run --with <pkg> <script>`
  (add `--no-project` when running outside this project).
- Manage dependencies with `uv add` / `uv remove` / `uv sync`; run one-off CLIs with `uvx <tool>`.
- `uv` manages the virtual environment (`.venv/`) itself: no `uv venv`, no `python -m venv`,
  no manual `activate`.
- If `uv` is not installed, ask the user before installing it or falling back to anything else.
- If this repo ever gains a Python environment, create it with `uv` and make sure `.venv/` is
  ignored by `.gitignore` (see `## .gitignore gotchas`).

### 8. Push policy

- **Never push without the user's explicit permission.** No `git push`, no force push, no creating
  pull requests, no tagging releases.
- Finishing a task means: changes committed locally, working tree clean, report delivered. Pushing
  is a separate, user-initiated action.
- Do not rewrite published history (`reset --hard`, `rebase`, `commit --amend` on pushed commits)
  without asking first.

### 9. Done checklist

Before reporting a task as finished:

- [ ] `git status` is clean — every change is committed.
- [ ] `tools/check.sh` passes (and `tools/test.sh` if the checker itself changed).
- [ ] Every new commit states what changed and why.
- [ ] `CHANGELOG.md` records the user-visible changes.
- [ ] `TODO.md` reflects the current state (new items added, finished items ticked).
- [ ] Nothing was pushed.
- [ ] No bare `python`/`pip` was used; Python work went through `uv`.
- [ ] Files use tabs, LF, UTF-8, and end with a newline.

### 10. Reporting

Report back to the user in this shape:

- **What changed** — the substance of the change and the files touched, not a bare file listing.
- **Commits** — the hash and subject of each commit.
- **Still open** — remaining `TODO.md` items, or anything deliberately deferred.
- **Not done** — actions intentionally skipped (for example: no push performed).

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
- `.venv/` is **not** ignored by default — add it yourself before creating a Python environment
  (see `## Workflow` §7).

## Conventions

- Commits use short conventional prefixes (`feat:`, `doc:`, `chore:`, `fix:`) with a Chinese
  summary and a what/why body; see `## Workflow` §3. Branch: `master`.
- Notable changes go in `CHANGELOG.md`; pending work goes in `TODO.md`.
- License: MIT.
