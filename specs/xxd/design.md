# Design: xxd

## Overview

`main()` passes `runtime.args()` to `cli.app.run`. It parses the arguments
into `Options`, handles `-h` and `-v`, applies the column and group defaults
(`layout`), and calls `commands.xxd.run_xxd`, which reads the input whole
with `readBytes`, then either renders a dump or reverts one. The dump and
revert functions are pure: they take `bytes` and return the output.

## Modules

| Module | Contents |
|---|---|
| `source/cli/args.loup` | `Options` (with `order: Endianness`), `parse_args` (xxd's first-letter option rules), `c_number` (C's `strtol(s, NULL, 0)`), `layout` (defaults, the column check, `-e`'s power of two), `little_endian`, `plain_message` |
| `source/cli/usage.loup` | `usage()`, `version_line()` |
| `source/cli/app.loup` | `run()`: usage errors give status 1 |
| `source/commands/xxd.loup` | `seek_start`, `dump_end`, `render_dump`, `run_xxd` (input and output files, `/dev/stdin`, `/dev/stdout`) |
| `source/commands/dump.loup` | lookup tables, `hex_offset`, `dump_lines`, `plain_lines`, `include_lines`, `c_name` |
| `source/commands/revert.loup` | `Reverted`, `revert_dump` (a port of xxd's `huntype`), `hex_value` |

## Layout of the default dump

xxd places byte `p` of a line at column `addrlen + 1 + (grplen * p) / group`,
with `grplen = 2 * group + 1` (or `8 * group + 1` for bits), and the
characters at `addrlen + 3 + (grplen * cols - 1) / group + p`. That is the
same as joining the groups with single spaces, padding the byte columns to
`(grplen * cols - 1) / group` characters and adding two spaces, which is
how `dump_lines` builds a line. Lines are pushed as pieces into one list and
joined once, because string `+=` in a long loop is quadratic in native Loup.

### Little-endian groups (`-e`)

`Options.order` names how a group reads, with `core.interchange`'s
`Endianness`: `BigEndian` (bytes in file order, the default) or
`LittleEndian` (`-e`). xxd puts byte `p` of an `-e` line at the position of
`p ^ (group - 1)`, which reverses each group when the group is a power of
two (hence its check), and puts the characters at
`addrlen + 2 + grplen * ceil(cols / group) + p`: every group, the last
too, has its full width. `dump_lines` writes the same line group by group:
a space between groups, `2 * (group - present)` spaces for the bytes a
short group lacks, then its bytes last to first; the byte columns are
`grplen * ceil(cols / group) - 1` wide. The pieces come from the same
tables, so memory stays the size of the output, as for the default dump.
xxd leaves a group that falls back to a whole line of `-c` bytes (with
`-g 0` or a `-g` larger than `-c`) unchecked, and garbles the line when
`-c` is not a power of two; `layout` refuses it with xxd's message.

## Seeking

The input is in memory, so `-s` is arithmetic, but xxd's results depend on
whether the input can seek, and `run_xxd` reproduces both cases: a named
file, or standard input that `isFile("/dev/stdin")` shows to be a file, may
start past the end (no output) but not before the start; a pipe may only
skip forward over bytes that exist.

## Reverting

`revert_dump` walks the dump byte by byte with xxd's state: the last three
digit values (`n1`, `n2`, `n3`), whether it is still reading a line's
offset (`p >= cols`), and whether leading garbage is being skipped. Two
digits in a row make a byte; three non-digits in a row, or `cols` bytes,
skip the rest of the line. Output goes into a list of byte values at a
position `have`; a file (or a regular file on standard output) can move
`have` anywhere, a pipe only forwards. An existing output file is read first
so that `-r` patches it. The result is written with one `writeBytes` call.

## Differences from the original

- Usage errors print a one-line message and a `Try` line; `-h` and `-v`
  print on standard output with status 0.
- `-a`, `-C`, `-d`, `-E`, `-n`, `-o` and `-R` are not implemented;
  `-r -b` is refused.
- `-e` with a group that falls back to a whole line of `-c` bytes, `-c`
  not a power of two, is an error (xxd prints garbled columns).
- `-r` keeps its output in memory and refuses offsets past 64 MiB. Binary
  output to standard output reopens `/dev/stdout`, which truncates a file.
- Input is read whole, so endless inputs never finish.
- `-i` names replace each non-alphanumeric character (not byte) with `_`.

## Error handling

Bad options return `Err(message)` from `parse_args` or `layout`; `run`
prints them (with the `Try` line unless xxd prints the bare message) and
returns 1. `run_xxd` checks the input with `exists` and `isDir` and the
output's directory before reading, because a native build cannot catch
`IoError`, and returns xxd's statuses 2, 3, 4, 5 and 255.

## Testing

- `tests/args_test.loup`: C numbers, option spellings, seek forms, operands,
  style conflicts, `-e`, defaults, column limits, usage errors.
- `tests/dump_test.loup`: tables, offsets, padded and grouped lines,
  little-endian lines (checked against xxd 2024-12-07), bits, plain and C
  output, names.
- `tests/revert_test.loup`: the character column, gaps, rewriting a file,
  a pipe that cannot seek back, `-s`, patching, plain input, the 64 MiB cap.
- `tests/xxd_test.loup`: seeking in files and pipes, `-l`, rendering.
- `tests/app_test.loup`: exit statuses through `run()`.
- `tests/e2e.sh`: 57 cases against the native binary, including pipes,
  output files, patching and round trips. The expected outputs come from the
  real xxd, and during development thousands of random inputs and option
  sets (and garbled dumps for `-r`) gave output identical to xxd's.
