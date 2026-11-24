#!/bin/sh
# Stage the unpublished package for Moon's registry-only script resolver.
# This fixture does not run lint.mbtx or modify the user's registry.
set -eu
cd "$(dirname "$0")/.."
mkdir -p tmp
fixture=$(mktemp -d "$PWD/tmp/script-home.XXXXXXXX")
registry=$fixture/registry
upstream=${MOON_HOME:-$HOME/.moon}/registry
moon package >&2
moon tree --json > "$fixture/tree.json"
jq -r '.modules[] | select(.source.kind == "registry") | [.name,.version] | @tsv' "$fixture/tree.json" |
while read -r module version; do
  mkdir -p "$registry/cache/$module" "$registry/index/user/$(dirname "$module")"
  cp "$upstream/cache/$module/$version.zip" "$registry/cache/$module/"
  cp "$upstream/index/user/$module.index" "$registry/index/user/$module.index"
done
module=$(jq -r '.modules[.root].name' "$fixture/tree.json")
version=$(jq -r '.modules[.root].version' "$fixture/tree.json")
archive=$registry/cache/$module/$version.zip
mkdir -p "$(dirname "$archive")" "$registry/index/user/$(dirname "$module")"
cp "_build/publish/$(printf '%s' "$module" | tr / -)-$version.zip" "$archive"
checksum=$(shasum -a 256 "$archive" | cut -d ' ' -f 1)
jq -c --arg checksum "$checksum" '
  . as $g | .modules[.root] | {name, version, $checksum, yanked: false,
    deps: ([$g.edges[] | select(.from == $g.root) |
      {key: .name, value: $g.modules[.to].version}] | from_entries)}
' "$fixture/tree.json" > "$registry/index/user/$module.index"
printf '%s\n' "$fixture"
