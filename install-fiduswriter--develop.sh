#!/usr/bin/env bash

set -e # fail on errors

which mmv | { echo please install mmv; exit 1; }
which git | { echo please install git; exit 1; }
which sed | { echo please install sed; exit 1; }

[ -d github.com/fiduswriter ] && { echo already installed?; exit 1; }

# citeproc-plus is required by fiduswriter
[ -d node_modules/citeproc-plus ] || { echo please install npm package citeproc-plus; exit 1; }

[ -d node_modules/biblatex-csl-converter ] || { echo please install npm package biblatex-csl-converter; exit 1; }
patch -p0 < patches/biblatex-csl-converter-2.0.0.diff

mkdir -p github.com/fiduswriter
(
  cd github.com/fiduswriter
  git clone --depth 1 https://github.com/fiduswriter/fiduswriter.git --branch develop
  mv fiduswriter fiduswriter--develop
  cd fiduswriter--develop

  cd fiduswriter
  # in fiduswriter/fiduswriter
  # "fix" import paths
  # symlink all files into the document package
  find . -mindepth 2 -name '*.js' | cut -d/ -f2 | uniq | grep -v document \
  | while read dir; do cp -asv "$(readlink -f $dir)"/*/ ./document/; done

  # symlink init.js to index.js
  find . -name init.js | while read f; do
    d=$(dirname "$f");
    if [ -f "$d/index.js" ]; then echo "skip $f"; continue; fi;
    echo "$d";
    ln -sv init.js $d/index.js;
  done

  # Uncaught ReferenceError: gettext is not defined
  # see fiduswriter/fiduswriter/document/management/commands/export_schema.py
  # prepend "var gettext = ..." before first line
  sed -i.bak '1s;^;var gettext = () => undefined\n\n;' document/static/js/modules/*/*.js
  sed -i.bak '1s;^;var gettext = () => undefined\n\n;' document/static/js/modules/*/*/*.js
  sed -i.bak '1s;^;var gettext = () => undefined\n\n;' document/static/js/modules/*/*/*/*.js
)

# in project root
# fix unknown file extension csljson
# no idea how to tell vite/rollup to use a "file-loader" for csljson files
# as suggested for webpack at https://github.com/fiduswriter/citeproc-plus

mmv \
  'node_modules/citeproc-plus/dist/assets/*.csljson' \
  'node_modules/citeproc-plus/dist/assets/#1.csl.json'

sed -i.bak -E 's|assets/([^"]+)\.csljson"|assets/\1.csl.json"|g' \
  node_modules/citeproc-plus/dist/*.js \
  node_modules/citeproc-plus/dist/*/*.js
