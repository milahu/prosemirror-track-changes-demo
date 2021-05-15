#!/usr/bin/env bash

fiduswriter_branch=master
#fiduswriter_branch=develop

# ---- config done ----

set -e # fail on errors

which mmv >/dev/null || { echo please install mmv; exit 1; }
which git >/dev/null || { echo please install git; exit 1; }
which sed >/dev/null || { echo please install sed; exit 1; }

fwdir=github.com/fiduswriter/fiduswriter

[ -d $fwdir ] && {
  echo fiduswriter is already installed in $fwdir
  echo
  echo solutions:
  echo "rm -rf $fwdir"
  echo "mv $fwdir $fwdir.bak.$(date +%Y-%m-%d.%H-%M-%S)"
  exit 1
}

# citeproc-plus is required by fiduswriter
[ -d node_modules/citeproc-plus ] || { echo please install npm package citeproc-plus; exit 1; }

[ -d node_modules/biblatex-csl-converter ] || { echo please install npm package biblatex-csl-converter; exit 1; }
patch -p0 --forward --reject-file=- < patches/biblatex-csl-converter-2.0.0.diff || true # allow to fail

mkdir -p $(dirname $fwdir) || true
(
  cd $(dirname $fwdir)
  git clone --depth 1 --branch $fiduswriter_branch https://github.com/fiduswriter/fiduswriter.git
  cd fiduswriter

  cd fiduswriter
  # in fiduswriter/fiduswriter
  # "fix" import paths
  # symlink all files into the document package
  find . -mindepth 2 -name '*.js' | cut -d/ -f2 | uniq | grep -v document | while read package
  do
    echo -e "\nmerge $package/ to document/"
    # cp -s needs absolute source path
    cp -asv "$(readlink -f $package)"/*/ ./document/ || true
    # allow to fail: "symbolic link exists"
  done

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
  echo -e '\nadd mock for gettext'
  sed -i.bak '1s;^;var gettext = () => undefined\n\n;' document/static/js/modules/*/*.js
  sed -i.bak '1s;^;var gettext = () => undefined\n\n;' document/static/js/modules/*/*/*.js
  sed -i.bak '1s;^;var gettext = () => undefined\n\n;' document/static/js/modules/*/*/*/*.js
)

# in project root
# fix unknown file extension csljson
# no idea how to tell vite/rollup to use a "file-loader" for csljson files
# as suggested for webpack at https://github.com/fiduswriter/citeproc-plus

echo -e '\nmove files: *.csljson -> *.csl.json'
mmv \
  'node_modules/citeproc-plus/dist/assets/*.csljson' \
  'node_modules/citeproc-plus/dist/assets/#1.csl.json'

sed -i.bak -E 's|assets/([^"]+)\.csljson"|assets/\1.csl.json"|g' \
  node_modules/citeproc-plus/dist/*.js \
  node_modules/citeproc-plus/dist/*/*.js
