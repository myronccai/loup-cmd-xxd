# Tasks: xxd

- [x] 1. Parse xxd's options: first-letter names, attached and separate values, C numbers, `--`, two operands
  - _Requirements: 3.4, 5.1, 5.2, 5.4_
- [x] 2. Apply column and group defaults per style and check the column limit
  - _Requirements: 1.2, 1.3, 2.1, 2.2, 2.4_
- [x] 3. Render the default and bits dumps with xxd's layout, padding the last line
  - _Requirements: 1.1, 1.4, 1.5, 2.1_
- [x] 4. Render plain and C include output, with names derived from the file
  - _Requirements: 2.2, 2.3_
- [x] 5. Apply `-s` and `-l` for files and pipes
  - _Requirements: 3.1, 3.2, 3.3_
- [x] 6. Port xxd's `huntype` for `-r` and `-r -p`: offsets, gaps, seeking back, patching, `-s`
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_
- [x] 7. Input and output files, standard streams and the exit statuses
  - _Requirements: 5.3_
- [x] 8. Unit tests and end-to-end tests of the native binary, checked against the real xxd
  - _Requirements: all_
