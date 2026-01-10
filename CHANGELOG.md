# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-01-10

### Added

- Initial release of multiple-cursor.nvim
- Word matching functionality - find all occurrences of word under cursor
- Select/Skip workflow with `<C-n>` to add and `<C-s>` to skip matches
- Remove last cursor with `<C-p>`
- Select all remaining matches with `<C-x>`
- Synchronized editing - changes apply to all selected positions
- Delete selected words with `d` key
- Change selected words with `c` key (delete + insert mode)
- Insert mode at all positions with `i` key
- User-configurable keymaps via setup()
- Customizable highlight groups
- Options for whole-word matching and case sensitivity
- User commands: `:MultipleCursorStart`, `:MultipleCursorClear`, `:MultipleCursorSelectAll`
- Vimdoc help file (`:h multiple-cursor`)
- Virtual text status showing match count and selection progress

[Unreleased]: https://github.com/khoido2003/multiple-cursor.nvim/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/khoido2003/multiple-cursor.nvim/releases/tag/v1.0.0
