# loup-cmd-xxd

`xxd` recreated in [Loup](https://code-craft.ai/references/loup): make a hex
dump of a file (hex, bits, plain or a C array), or turn a dump back into
bytes with `-r`.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary.

It follows the xxd that ships with Vim (version 2024-12-07): the same layout
rules, option spellings, C-style numbers and the same `-r` parser, so its
output matches xxd's byte for byte for the options it supports.

## Requirements

- Loup 1.26.0 or later:

  ```sh
  curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
  ```

- `make`, and `clang` 17 or later for the native build.

## Usage

```sh
make build                 # native binary: build/xxd
make ci                    # check, unit tests, build, end-to-end tests
make run ARGS="-g 1 -l 32 README.md"   # run from source with loup run
```

```text
$ build/xxd tests/fixtures/sample.txt
00000000: 4865 6c6c 6f2c 2078 7864 210a 4279 7465  Hello, xxd!.Byte
00000010: 7320 696e 2c20 6865 7820 6f75 742e 0a    s in, hex out..
$ build/xxd -g 1 -c 8 -l 16 -u tests/fixtures/sample.txt
00000000: 48 65 6C 6C 6F 2C 20 78  Hello, x
00000008: 78 64 21 0A 42 79 74 65  xd!.Byte
$ build/xxd -b -l 6 tests/fixtures/sample.txt
00000000: 01001000 01100101 01101100 01101100 01101111 00101100  Hello,
$ build/xxd -p tests/fixtures/sample.txt
48656c6c6f2c20787864210a427974657320696e2c20686578206f75742e
0a
$ build/xxd -i -c 8 -l 10 tests/fixtures/sample.txt
unsigned char tests_fixtures_sample_txt[] = {
  0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x2c, 0x20, 0x78,
  0x78, 0x64
};
unsigned int tests_fixtures_sample_txt_len = 10;
$ build/xxd -s -6 tests/fixtures/sample.txt
00000019: 206f 7574 2e0a                            out..
$ build/xxd -p tests/fixtures/sample.txt | build/xxd -r -p
Hello, xxd!
Bytes in, hex out.
$ printf '00000004: 4142\n' | build/xxd -r | od -c
0000000  \0  \0  \0  \0   A   B
0000006
```

`xxd [OPTIONS] [INFILE [OUTFILE]]`; without INFILE (or with `-`) it reads
standard input, without OUTFILE (or with `-`) it writes standard output.

| Option | Meaning |
|---|---|
| `-c COLS` | bytes per line (default 16; `-b` 6, `-i` 12, `-p` 30; at most 256 except with `-i` and `-p`; `-p -c 0` means one line) |
| `-g BYTES` | bytes per group in the default and `-b` dumps (default 2; `-b` 1) |
| `-l LEN` | stop after LEN bytes |
| `-s [+][-]OFFSET` | start at OFFSET (`-` counts from the end); with `-r`, add OFFSET to the dump's offsets |
| `-u` | upper-case hex digits |
| `-b` | binary digits instead of hex (also with `-i`) |
| `-p`, `-ps` | plain hex, no offsets or characters |
| `-i` | a C array (named after INFILE when there is one) |
| `-r` | reverse: turn a default or `-p` dump into bytes |
| `-h`, `-v` | help, version |

As in xxd, options come before the operands and are recognised by their
first letter (`-u`, `-upper` and `--upper` are the same); values may be
attached (`-c8`) or separate (`-c 8`, `-cols 8`), and are C numbers (`0x10`,
`020`). With `-r`, a dump's lines may come in any order: gaps are filled
with zero bytes, an existing output file is patched rather than truncated,
and writing backwards into a pipe fails.

Exit status: `0` on success, `1` for bad options or columns, `2` if the
input cannot be opened, `3` if the output cannot be opened, `4` if `-s`
points before the start of the input, `5` if `-r` cannot seek backwards
(or past 64 MiB), `255` if `-r` is asked for a `-i` or `-b` dump.

## Differences from the original

- **Usage errors** print a one-line message and
  `Try 'xxd -h' for more information.` (status 1) instead of the whole usage
  text. `-h` prints the help on standard output with status 0 (xxd: standard
  error, status 1), and `-v` prints `xxd (loup-cmd-xxd) 0.1.0` on standard
  output.
- **Not implemented:** `-a` (autoskip), `-C`, `-d`, `-E` (EBCDIC), `-e`
  (little-endian), `-n NAME`, `-o OFFSET` and `-R` (colour; output is never
  coloured). They are rejected as invalid options. `-r -b` (reverting a bits
  dump) is refused like `-r -i`.
- **`-r` builds its output in memory** and writes it at the end, so a dump
  whose offsets reach past 64 MiB is refused (xxd would pad a pipe with zeros
  or seek a sparse file). When standard output is a file, `-r` reopens
  `/dev/stdout`, which truncates it: write `-r` output with its own `>`
  redirection, not `>>` or after other output in the same redirection.
- The whole input is read before anything is written (Loup 1.26 reads files
  and standard input whole), so an endless input such as `/dev/urandom`
  never finishes, even with `-l`. Use finite input
  (`head -c 64 /dev/urandom | xxd`).
- `-i` builds the array name from the characters of the file name, so a
  non-ASCII character becomes one `_` (xxd writes one `_` per byte).
- Files are created with the default permissions of Loup's `writeBytes`
  (`0644`) rather than `0666` minus the umask.

## Layout

```text
source/main.loup             # entry point
source/appinfo.loup          # name, version, exit statuses
source/cli/args.loup         # xxd's option rules, C numbers, column defaults
source/cli/usage.loup        # -h and -v text
source/cli/app.loup          # run(): parse, help/version, run_xxd, exit status
source/commands/xxd.loup     # input, -s/-l, output; run_xxd()
source/commands/dump.loup    # default, -b, -p and -i dumps
source/commands/revert.loup  # -r and -r -p (xxd's huntype)
tests/*_test.loup            # unit tests (make test)
tests/e2e.sh                 # end-to-end tests of build/xxd (make e2e)
tests/fixtures/sample.txt  # the sample input
specs/xxd/                   # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.
