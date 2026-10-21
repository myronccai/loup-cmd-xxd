# Requirements: xxd

## Introduction

`xxd` makes a hex dump of a file or of standard input, and can turn a dump
back into the original bytes. This repository recreates the xxd that ships
with Vim (2024-12-07) in Loup: the default dump, binary digits, plain hex, C
include files, and reverting default and plain dumps. It is one of the
Linux byte tools in the loup-cmd series.

## Requirements

### Requirement 1: The default dump

**User Story:** As a developer, I want to see the bytes of a file with their
offsets and characters so that I can inspect binary data.

#### Acceptance Criteria

1. THE program SHALL print, per line, the offset of the first byte as at
   least eight hex digits and a colon, the bytes as hex pairs in groups, two
   spaces, and the bytes as characters (`.` for anything outside 0x20-0x7E).
2. WHEN `-c COLS` is given, THE program SHALL put COLS bytes on a line
   (default 16, at most 256); `-c 0` SHALL mean the default.
3. WHEN `-g BYTES` is given, THE program SHALL group BYTES bytes (default
   2); 0 or more than COLS SHALL mean one group per line.
4. WHEN the last line is short, THE program SHALL pad it so that the
   characters line up with the lines above.
5. WHEN `-u` is given, THE program SHALL use upper-case hex digits (not in
   offsets).

### Requirement 2: Other styles

**User Story:** As a developer, I want other dump styles so that I can use
the bytes in scripts and programs.

#### Acceptance Criteria

1. WHEN `-b` is given, THE program SHALL show eight binary digits per byte
   (default 6 bytes a line, groups of 1).
2. WHEN `-p` is given, THE program SHALL print bare hex pairs, 30 bytes a
   line by default, and `-c 0` SHALL put everything on one line.
3. WHEN `-i` is given, THE program SHALL print the bytes as a C initializer
   (12 a line by default, `0x` or with `-u` `0X` literals, `0b` literals with
   `-b`), wrapped in `unsigned char NAME[] = {` and `unsigned int NAME_len`
   when the input is a named file, NAME being the file name with other
   characters turned into `_` and `__` before a leading digit.
4. WHEN `-p` is combined with `-b` or `-i`, or `-e` with `-b`, `-p` or
   `-i`, THE program SHALL report
   `only one of -b, -e, -u, -p, -i can be used` and exit with status 1.
5. WHEN `-e` is given, THE program SHALL write the default dump with each
   group (default 4 bytes) as one little-endian number: its bytes last to
   first. A group cut short by the end of the input or of a line SHALL keep
   its width, its digits right-aligned, and the characters SHALL stay in
   file order, as xxd writes them.
6. WHEN `-e` is given with a group that is not a power of two (as given,
   or the line's width that a `-g` of 0 or larger than `-c` falls back
   to), THE program SHALL report `number of octets per group must be a
   power of 2 with -e.` and exit with status 1; WHEN `-r` is given with
   `-e`, it SHALL report `Sorry, cannot revert this type of hexdump` and
   exit with status 255.

### Requirement 3: Choosing the bytes

**User Story:** As a developer, I want to dump part of a file so that I can
look at one region.

#### Acceptance Criteria

1. WHEN `-s OFFSET` is given, THE program SHALL start at OFFSET, `-s -N`
   SHALL start N bytes before the end, and offsets SHALL show file positions.
2. WHEN `-s` points before the start of the input, or (for a pipe) past its
   end or from its end, THE program SHALL print `xxd: Sorry, cannot seek.`
   and exit with status 4.
3. WHEN `-l LEN` is given, THE program SHALL stop after LEN bytes; a
   negative LEN SHALL mean no limit.
4. THE program SHALL read numbers as C does: `0x` hexadecimal, a leading
   `0` octal, otherwise decimal.

### Requirement 4: Reverting

**User Story:** As a developer, I want to edit a dump and turn it back into
bytes so that I can patch binary files.

#### Acceptance Criteria

1. WHEN `-r` is given, THE program SHALL read each line's offset and up to
   COLS hex pairs, ignore the character column, and write the bytes at that
   offset.
2. WHEN `-r -p` is given, THE program SHALL read hex pairs and ignore white
   space and line breaks.
3. WHEN an offset leaves a gap, THE program SHALL fill it with zero bytes;
   WHEN it goes backwards, THE program SHALL overwrite earlier output in a
   file and report `xxd: Sorry, cannot seek backwards.` (status 5) in a pipe.
4. WHEN the output file exists, THE program SHALL patch it instead of
   truncating it.
5. WHEN `-r -s OFFSET` is given, THE program SHALL add OFFSET to the dump's
   offsets.
6. WHEN `-r` is combined with `-i` (or `-b`), THE program SHALL report
   `xxd: Sorry, cannot revert this type of hexdump` with status 255.

### Requirement 5: Command line

**User Story:** As a script author, I want xxd's option syntax and exit
statuses so that existing scripts keep working.

#### Acceptance Criteria

1. THE program SHALL recognise options by their first letter, accept `--`
   spellings and attached or separate values, stop at the first operand or
   `--`, and take up to two operands (input and output; `-` for the
   standard streams).
2. WHEN an option is unknown, a value is missing or there are more than two
   operands, THE program SHALL print a message and the `Try` line and exit
   with status 1.
3. WHEN the input does not exist or is a directory, THE program SHALL exit
   with status 2; WHEN the output cannot be created, with status 3.
4. WHEN `-h` or `-v` is given, THE program SHALL print the help or
   `xxd (loup-cmd-xxd) 0.1.0` and exit with status 0.
