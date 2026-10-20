# AGENTS.md

This repository recreates `xxd` (the hex dump tool that ships with Vim) in
the Loup programming language, as part of the loup-cmd series of example
applications: default, bits, plain and C-include dumps, and `-r` to turn a
dump back into bytes. The program is `host.dual` Loup built as a native
executable.

## Skills

| Skill | Location | Use it when |
|-------|----------|-------------|
| `loup-programmer` | [skills/loup-programmer/SKILL.md](skills/loup-programmer/SKILL.md) | Writing, reviewing, debugging or explaining Loup code: `.lpscr`, `.loup`, `.lphc`, `.lpweb` or `.lpfree` source files, `.lppkg` manifests, `@mode(...)` directives, or the `loup` / `loup-bootstrap` commands. |

Read `skills/loup-programmer/SKILL.md` before writing or changing any Loup code
in this repository. It links to detailed references under
`skills/loup-programmer/references/` for syntax, types and ownership, execution
modes and projects, errors and diagnostics, the standard library, and common
mistakes. Load those only as needed.

## Code layout

```text
.
├── package.lppkg                # Loup manifest: name, version, toolchain, [build] entry, [test] pattern
├── Makefile                     # run, check, test, build, e2e, ci, clean
├── source/                      # all Loup code; modules import each other by path from here
│   ├── main.loup                # entry point: func main() calls run(runtime.args())
│   ├── appinfo.loup             # APP_NAME, APP_VERSION, APP_SUMMARY, xxd's exit statuses (0-5, 255)
│   ├── cli/
│   │   ├── args.loup            # struct Options, parse_args(): xxd's option rules; c_number(), layout()
│   │   ├── usage.loup           # usage(), version_line()
│   │   └── app.loup             # run(): parse, -h/-v, columns, run_xxd, exit status
│   └── commands/
│       ├── xxd.loup             # seek_start(), dump_end(), render_dump(), run_xxd(): input and output
│       ├── dump.loup            # dump_lines(), plain_lines(), include_lines(), c_name()
│       └── revert.loup          # revert_dump(): -r and -r -p, a port of xxd's huntype()
├── tests/
│   ├── *_test.loup              # unit tests: func test_*(): void
│   ├── e2e.sh                   # end-to-end tests of the native binary
│   └── fixtures/sample.txt    # sample input
├── specs/xxd/                   # requirements.md, design.md, tasks.md
├── skills/loup-programmer/      # the Loup skill and its references
├── .github/workflows/ci.yml     # installs Loup and runs `make ci`
└── build/                       # build output (git-ignored)
```

## Build, run and test

Prerequisites: Loup 1.26.0 (`loup` and `loup-bootstrap` on `PATH`), `make`,
and `clang` 17 or later for native builds.

Loup Lite comes from <https://github.com/code-craft-ai-company/loup-releases>;
[README.md](README.md#installing-loup-lite) has the install commands.

| Task | Command | Notes |
|------|---------|-------|
| Run from source | `make run ARGS="-g 1 -l 32 README.md"` | `loup run source/main.loup -- ARGS` |
| Type-check | `make check` | checks `source/main.loup` and every module it imports; tests are not checked |
| Run all tests | `make test` | every `tests/*_test.loup` |
| Run matching tests | `make test TEST_ARGS="--filter plain"` | tests whose name contains `plain` |
| Run one test file | `make test TEST_ARGS="--file tests/args_test.loup"` | |
| Build | `make build` | native binary at `build/xxd` |
| Run the binary | `build/xxd --help` | |
| End-to-end tests | `make e2e` | runs `tests/e2e.sh build/xxd`: output compared byte for byte |
| Everything CI runs | `make ci` | check, test, build, e2e, then `build/xxd --version` |
| Clean | `make clean` | removes `build/` and `.temp/` |

Run `make ci` before reporting a change as done. `loup run` and the native
build do not support the same things, so a change can pass `make test` and
still fail `make build`.

Do not call `loup test` or `loup check` directly on Linux x86-64. There `loup`
is the self-hosted driver: it refuses `check`, and its test runner cannot
resolve this project's imports. The Makefile uses `loup-bootstrap` (Stage0) for
both, and sets `LOUPPATH=source` for tests.

## Making a change

1. Update the spec in `specs/xxd/` (see [specs/README.md](specs/README.md)).
2. Change the code under `source/`.
3. Add or update unit tests in `tests/` and cases in `tests/e2e.sh`.
4. Run `make ci`.
5. Tick the finished tasks in `specs/xxd/tasks.md`.

Keep behaviour in pure functions that return values (the dump functions
return the output as a list of pieces; `revert_dump` returns the bytes and
any error) so unit tests can check them; only `run_xxd` reads and writes.
Unit tests run from the repository root, so they open fixtures as
`tests/fixtures/...`, and build `bytes` with `bytesFromInts([...])`.

The layout rules in `dump.loup` and the parser in `revert.loup` mirror
xxd.c; check any change against the real `xxd` on many random inputs, not
only the tests.

## Conventions

- Every source file is `@mode(host.dual)` with the `.loup` extension. Only
  `source/main.loup` has a `main()`.
- Modules import each other by path from `source/`:
  `from cli.args import (Options);`. Tests import them the same way. Do not
  use relative imports (`from .args import ...`): the self-hosted `loup run`
  on Linux x86-64 fails on them.
- Struct fields read from another module must be `pub`.
- The native build supports less than `loup run` does. For example,
  `list.is_empty()` fails native codegen (`E-CODEGEN-UNHANDLED-METHOD`); use
  `len() == 0`.
- Native-build pitfalls this code works around: construct a struct only in
  the module that defines it (hence `default_options`, `new_reverted`); do
  not put escapes such as `\n` inside `i"..."`; index `bytes` (`data[k]`)
  instead of iterating them with `for`; `IoError` cannot be caught, so check
  `exists()` and `isDir()` before reading; build large outputs as a list of
  pieces and `join("")` them once (string `+=` in a long loop is quadratic
  natively); write binary output to `/dev/stdout` with a single
  `writeBytes` call (it reopens and truncates the file).
- Struct fields that are assigned after construction must be `pub var`.
- Keep `APP_VERSION` in `source/appinfo.loup` equal to `version` in
  `package.lppkg`.
- The skill's examples use the `loup init` layout (`src/`, `tests/`, and
  `from ..src.x import` in tests). This project uses `source/` and
  `tests/` with plain imports; follow this file.
- The skill documents toolchain 1.25.1; this template targets 1.26.0. When
  they disagree, trust the toolchain's behaviour.
