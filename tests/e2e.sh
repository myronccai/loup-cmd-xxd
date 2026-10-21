#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte) and exit status with the expected ones.
#
# usage: tests/e2e.sh BINARY
#
# The cases run inside tests/fixtures so that file names in the expected
# output stay short; scratch files go in $TMP.

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cd "$(dirname "$0")/fixtures" || exit 2
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_err NAME STATUS EXPECTED_STDERR [ARGS...]
# Runs BINARY ARGS... and compares standard error (and the exit status).
check_err() {
    local name=$1 want_status=$2 want=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > /dev/null 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && [ "$(cat "$TMP/err")" == "$want" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check_pipe NAME STATUS EXPECTED_FILE [ARGS...]
# As check_file, but standard input and output are pipes, which cannot seek.
check_pipe() {
    local name=$1 want_status=$2
    cp "$3" "$TMP/want"
    shift 3
    cat "${IN:-/dev/null}" | "$BIN" "$@" 2> "$TMP/err" | cat > "$TMP/out"
    local status=${PIPESTATUS[1]}
    if [ "$status" -eq "$want_status" ] && cmp -s "$TMP/want" "$TMP/out"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$TMP/want") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check_output NAME STATUS EXPECTED_FILE OUTFILE [ARGS...]
# Runs BINARY ARGS... and compares the file OUTFILE it writes.
check_output() {
    local name=$1 want_status=$2 want_file=$3 out_file=$4
    shift 4
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/stdout" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$out_file" && [ ! -s "$TMP/stdout" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$out_file") | sed 's/^/    /' | head -20
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# --- hex dumps ---------------------------------------------------------------

check "default" 0 '00000000: 4865 6c6c 6f2c 2078 7864 210a 4279 7465  Hello, xxd!.Byte
00000010: 7320 696e 2c20 6865 7820 6f75 742e 0a    s in, hex out..
' sample.txt

check "-g 1" 0 '00000000: 48 65 6c 6c 6f 2c 20 78 78 64 21 0a 42 79 74 65  Hello, xxd!.Byte
00000010: 73 20 69 6e 2c 20 68 65 78 20 6f 75 74 2e 0a     s in, hex out..
' -g 1 sample.txt

check "-g 4 -c 8" 0 '00000000: 48656c6c 6f2c2078  Hello, x
00000008: 7864210a 42797465  xd!.Byte
00000010: 7320696e 2c206865  s in, he
00000018: 78206f75 742e0a    x out..
' -g 4 -c 8 sample.txt

check "-c 10 -g 3 -u" 0 '00000000: 48656C 6C6F2C 207878 64  Hello, xxd
0000000a: 210A42 797465 732069 6E  !.Bytes in
00000014: 2C2068 657820 6F7574 2E  , hex out.
0000001e: 0A                       .
' -c 10 -g 3 -u sample.txt

check "long option names" 0 '00000000: 48 65 6c 6c  Hell
00000004: 6f 2c        o,
' -cols 4 --len 6 -groupsize 1 sample.txt

check "C numbers" 0 '00000010: 7320 696e 2c20 6865                      s in, he
' -s 0x10 -l 010 sample.txt

printf '\000\001\037 ~\177\200\377' > "$TMP/bytes.bin"
check "unprintable bytes" 0 '00000000: 0001 1f20 7e7f 80ff                      ... ~...
' "$TMP/bytes.bin"

: > "$TMP/empty"
check "empty input"       0 '' "$TMP/empty"
IN=sample.txt check "stdin" 0 '00000000: 4865 6c6c 6f                             Hello
' -l 5

# --- -s and -l -------------------------------------------------------------

check "-s -l" 0 '00000005: 2c20 7878 6421 0a42 7974                 , xxd!.Byt
' -s 5 -l 10 sample.txt
check "-s from the end" 0 '0000001a: 6f75 742e 0a                             out..
' -s -5 sample.txt
check "-s past the end"   0 '' -s 100 sample.txt
check "-l 0"              0 '' -l 0 sample.txt
check "-l negative"       0 '00000000: 4865 6c6c 6f2c 2078 7864 210a 4279 7465  Hello, xxd!.Byte
00000010: 7320 696e 2c20 6865 7820 6f75 742e 0a    s in, hex out..
' -l -1 sample.txt
printf '00000003: 6c6f 2c20                                lo, \n' > "$TMP/want-rel"
IN=sample.txt check_pipe "-s +N in a pipe" 0 "$TMP/want-rel" -s +3 -l 4
IN=sample.txt check_pipe "-s past the end of a pipe" 4 /dev/null -s 40
IN=sample.txt check_pipe "-s -N in a pipe" 4 /dev/null -s -4

# --- little-endian groups (-e) ------------------------------------------------
# Expected output as xxd 2024-12-07 writes it: each group of bytes as one
# little-endian number, a short group's digits right-aligned in its width.

check "-e" 0 '00000000: 6c6c6548 78202c6f 0a216478 65747942  Hello, xxd!.Byte
00000010: 6e692073 6568202c 756f2078   0a2e74  s in, hex out..
' -e sample.txt

check "-e -g 8" 0 '00000000: 78202c6f6c6c6548 657479420a216478  Hello, xxd!.Byte
00000010: 6568202c6e692073   0a2e74756f2078  s in, hex out..
' -e -g 8 sample.txt

check "-e -c 12" 0 '00000000: 6c6c6548 78202c6f 0a216478  Hello, xxd!.
0000000c: 65747942 6e692073 6568202c  Bytes in, he
00000018: 756f2078   0a2e74           x out..
' -e -c 12 sample.txt

check "-e -c 6: groups cut by the line" 0 '00000000: 6c6c6548     2c6f  Hello,
00000006: 64787820     0a21   xxd!.
0000000c: 65747942     2073  Bytes 
00000012: 202c6e69     6568  in, he
00000018: 756f2078     2e74  x out.
0000001e:       0a           .
' -e -c 6 sample.txt

check "-e -u -c 10 -g 2" 0 '00000000: 6548 6C6C 2C6F 7820 6478  Hello, xxd
0000000a: 0A21 7942 6574 2073 6E69  !.Bytes in
00000014: 202C 6568 2078 756F 2E74  , hex out.
0000001e:   0A                      .
' -e -u -c 10 -g 2 sample.txt

check "-e -g 0: one group a line" 0 '00000000: 657479420a21647878202c6f6c6c6548  Hello, xxd!.Byte
00000010:                         6e692073  s in
' -e -g 0 -l 20 sample.txt

printf '00000003: 202c6f6c 21647878       0a           lo, xxd!.\n' > "$TMP/want-le"
IN=sample.txt check_pipe "-e -s +N in a pipe" 0 "$TMP/want-le" -e -s +3 -l 9

check_err "-e -g 3"             1 'xxd: number of octets per group must be a power of 2 with -e.' -e -g 3 sample.txt
check_err "-e -c 12 -g 0"       1 'xxd: number of octets per group must be a power of 2 with -e.' -e -c 12 -g 0 sample.txt
check_err "-e and -b"           1 'xxd: only one of -b, -e, -u, -p, -i can be used' -e -b sample.txt
check_err "-p and -e"           1 'xxd: only one of -b, -e, -u, -p, -i can be used' -p -e sample.txt
IN=sample.txt check_err "-r -e" 255 'xxd: Sorry, cannot revert this type of hexdump' -r -e

# --- bits, plain and C include -----------------------------------------------

check "-b" 0 '00000000: 01001000 01100101 01101100 01101100 01101111 00101100  Hello,
00000006: 00100000 01111000 01111000 01100100 00100001 00001010   xxd!.
0000000c: 01000010 01111001 01110100 01100101 01110011 00100000  Bytes 
00000012: 01101001 01101110 00101100 00100000 01101000 01100101  in, he
00000018: 01111000 00100000 01101111 01110101 01110100 00101110  x out.
0000001e: 00001010                                               .
' -b sample.txt

check "-b -c 4 -g 2 -l 9" 0 '00000000: 0100100001100101 0110110001101100  Hell
00000004: 0110111100101100 0010000001111000  o, x
00000008: 01111000                           x
' -b -c 4 -g 2 -l 9 sample.txt

check "-p" 0 '48656c6c6f2c20787864210a427974657320696e2c20686578206f75742e
0a
' -p sample.txt
check "-p -c 4 -l 10" 0 $'48656c6c\n6f2c2078\n7864\n' -p -c 4 -l 10 sample.txt
check "-p -u -c 5 -l 10" 0 $'48656C6C6F\n2C20787864\n' -p -u -c 5 -l 10 sample.txt
check "-ps -c 0"          0 $'48656c6c6f2c20787864210a427974657320696e2c20686578206f75742e0a\n' -ps -c 0 sample.txt
check "-p empty"          0 '' -p "$TMP/empty"
check "-p -c 0 empty"     0 $'\n' -p -c 0 "$TMP/empty"

check "-i" 0 'unsigned char sample_txt[] = {
  0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x2c, 0x20, 0x78, 0x78, 0x64, 0x21, 0x0a,
  0x42, 0x79, 0x74, 0x65, 0x73, 0x20, 0x69, 0x6e, 0x2c, 0x20, 0x68, 0x65,
  0x78, 0x20, 0x6f, 0x75, 0x74, 0x2e, 0x0a
};
unsigned int sample_txt_len = 31;
' -i sample.txt

check "-i -u -c 4 -l 6" 0 'unsigned char sample_txt[] = {
  0X48, 0X65, 0X6C, 0X6C,
  0X6F, 0X2C
};
unsigned int sample_txt_len = 6;
' -i -u -c 4 -l 6 sample.txt

check "-i -b" 0 'unsigned char sample_txt[] = {
  0b01001000, 0b01100101, 0b01101100, 0b01101100
};
unsigned int sample_txt_len = 4;
' -i -b -l 4 sample.txt

IN=sample.txt check "-i from stdin" 0 $'  0x48, 0x65, 0x6c\n' -i -l 3
cp sample.txt "$TMP/2nd copy.txt"
check "-i name from a path" 0 $'unsigned char '"${TMP//[^a-zA-Z0-9]/_}"$'_2nd_copy_txt[] = {\n  0x48\n};\nunsigned int '"${TMP//[^a-zA-Z0-9]/_}"$'_2nd_copy_txt_len = 1;\n' \
    -i -l 1 "$TMP/2nd copy.txt"
name="${TMP//[^a-zA-Z0-9]/_}_empty"
check "-i empty file"     0 "unsigned char ${name}[] = {
};
unsigned int ${name}_len = 0;
" -i "$TMP/empty"

# --- output file -------------------------------------------------------------

printf '00000000: 4865 6c6c 6f                             Hello\n' > "$TMP/want-dump"
check_output "dump to a file" 0 "$TMP/want-dump" "$TMP/dump.txt" -l 5 sample.txt "$TMP/dump.txt"

# --- reverting ---------------------------------------------------------------

xxd_dump='00000000: 0001 1f20 7e7f 80ff                      ... ~...
'
printf '%s' "$xxd_dump" > "$TMP/dump"
IN="$TMP/dump" check_file "-r"          0 "$TMP/bytes.bin" -r
IN="$TMP/dump" check_pipe "-r to a pipe" 0 "$TMP/bytes.bin" -r
printf '00010203\n7f80ff\n' > "$TMP/plain"
printf '\000\001\002\003\177\200\377' > "$TMP/plain.bin"
check_file "-r -p"              0 "$TMP/plain.bin" -r -p "$TMP/plain"
printf '0001 0203 7f\n  80ff\n' > "$TMP/spaced"
check_file "-r -p with spaces"  0 "$TMP/plain.bin" -r -ps "$TMP/spaced"

printf '00000000: 4142 4344 4546 4748 494a 4b4c 4d4e 4f50  ABCDEFGHIJKLMNOP\n' > "$TMP/wide"
printf 'ABCDEFGH' > "$TMP/half"
printf '00000000: 4142 4344 4546 4748  ABCDEFGH\n00000008: 494a 4b4c 4d4e 4f50  IJKLMNOP\n' > "$TMP/narrow"
check_file "-r keeps 16 bytes a line" 0 "$TMP/half" -r -c 8 "$TMP/wide"
printf 'ABCDEFGHIJKLMNOP' > "$TMP/full"
check_file "-r -c 8"            0 "$TMP/full" -r -c 8 "$TMP/narrow"

printf '00000004: 4142\n' > "$TMP/gap"
printf '\000\000\000\000AB' > "$TMP/gap.bin"
check_file "-r fills gaps"      0 "$TMP/gap.bin" -r "$TMP/gap"
printf '\000\000\000\000\000\000AB' > "$TMP/gap2.bin"
check_file "-r -s adds offset"  0 "$TMP/gap2.bin" -r -s 2 "$TMP/gap"

printf '00000004: 4142\n00000000: 4344\n' > "$TMP/backwards"
printf 'CD\000\000AB' > "$TMP/backwards.bin"
check_file "-r rewrites a file" 0 "$TMP/backwards.bin" -r "$TMP/backwards"
IN="$TMP/backwards" check_pipe "-r cannot seek a pipe" 5 "$TMP/gap.bin" -r
printf 'ABCDEFGH' > "$TMP/patched"
printf '2: 7a7a\n' > "$TMP/patch"
printf 'ABzzEFGH' > "$TMP/patched.want"
check_output "-r patches a file" 0 "$TMP/patched.want" "$TMP/patched" -r "$TMP/patch" "$TMP/patched"

xxd_round="$TMP/round"
head -c 600 "$BIN" > "$TMP/sample.bin"
"$BIN" -c 24 -g 5 "$TMP/sample.bin" > "$xxd_round"
check_file "round trip"         0 "$TMP/sample.bin" -r -c 24 "$xxd_round"
"$BIN" -p "$TMP/sample.bin" > "$xxd_round"
check_file "round trip -p"      0 "$TMP/sample.bin" -r -p "$xxd_round"

# --- errors and usage --------------------------------------------------------

check_err "missing file"        2 'xxd: nope.bin: No such file or directory' nope.bin
check_err "directory"           2 'xxd: Is a directory' .
check_err "output is a directory" 3 "xxd: $TMP: Is a directory" sample.txt "$TMP"
check_err "output dir missing"  3 "xxd: $TMP/no/out: No such file or directory" sample.txt "$TMP/no/out"
check_err "too many columns"    1 'xxd: invalid number of columns (max. 256).' -c 300 sample.txt
check_err "-p and -i"           1 'xxd: only one of -b, -e, -u, -p, -i can be used' -p -i sample.txt
check_err "-r -i"             255 'xxd: Sorry, cannot revert this type of hexdump' -r -i sample.txt
check_err "-s before start"     4 'xxd: Sorry, cannot seek.' -s -100 sample.txt
check_err "unknown option"      1 "xxd: invalid option '-z'
Try 'xxd -h' for more information." -z sample.txt
check_err "missing value"       1 "xxd: option '-c' requires an argument
Try 'xxd -h' for more information." -c
check_err "extra operand"       1 "xxd: extra operand 'c'
Try 'xxd -h' for more information." a b c
check "-- ends options"         0 '00000000: 4865                                     He
' -l 2 -- sample.txt
check "version"                 0 $'xxd (loup-cmd-xxd) 0.1.0\n' -v

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
