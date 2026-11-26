name = "totto2727/mbtlint"

version = "0.1.0"

description = "Programmable MoonBit AST lint rules for lint.mbtx"

readme = "README.mbt.md"

repository = "https://github.com/totto2727-org/mbtlint"

license = "MIT"

keywords = [ "moonbit", "lint", "static-analysis" ]

preferred_target = "wasm"

supported_targets = "wasm+js+native"

import {
  "moonbitlang/async@0.22.9",
  "moonbitlang/parser@0.4.9",
  "moonbitlang/lexer@0.4.5",
  "moonbitlang/x@0.5.7",
  "totto2727/admiral@0.7.0",
}
