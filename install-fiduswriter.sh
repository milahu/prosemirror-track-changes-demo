#!/usr/bin/env bash

#fiduswriter_branch=master
fiduswriter_branch=develop

# ---- config done ----

set -e # fail on errors

which mmv >/dev/null || { echo please install mmv; exit 1; }
which git >/dev/null || { echo please install git; exit 1; }
which sed >/dev/null || { echo please install sed; exit 1; }
which ncu >/dev/null || { echo please install ncu: npm i -g npm-check-updates; exit 1; }

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

#[ -d node_modules/prosemirror-model ] || { echo please install npm package prosemirror-model; exit 1; }
## fix: looks like multiple versions of prosemirror-model were loaded
## https://github.com/ueberdosis/tiptap/issues/577
#prosemirror_model_version=$(cat node_modules/prosemirror-model/package.json | jq -r .version)

mkdir -p $(dirname $fwdir) || true
(
  cd $(dirname $fwdir)
  ! [ -e fiduswriter ] &&
  git clone --depth 1 --branch $fiduswriter_branch https://github.com/fiduswriter/fiduswriter.git
  cd fiduswriter

  cd fiduswriter

  # https://github.com/fiduswriter/fiduswriter/wiki/Installation-for-developers

  cp configuration-default.py configuration.py

  # debian
  which apt &>/dev/null && {
    sudo apt install libjpeg-dev python3-dev python3-pip gettext zlib1g-dev git npm nodejs build-essential
    python3 manage.py setup
  }

  # nixos
  which nix-shell &>/dev/null && {
    nix-shell ../../../../shell.nix \
      --run 'python3 manage.py setup'
  }

  # pip on nixos will break python-magic -> install only nixos.python_magic
  #pip3 install -r requirements.txt



  # in fiduswriter/fiduswriter
  # "fix" import paths
  # symlink all files into the document package
  echo -e '\nmerging packages (apply migrations) ...'
  find . -mindepth 2 -name '*.js' | cut -d/ -f2 | uniq \
  | grep -v -e document -e '\.transpile' -e static-libs | while read package
  do
    echo -e "\nmerging $package/ to document/"
    # cp -s needs absolute source path
    cp -asv "$(readlink -f $package)"/*/ ./document/ || true
    # allow to fail: "symbolic link exists"
  done

  package=static-libs
  echo -e "\nmerging $package/ to document/static/"
  cp -asv "$(readlink -f $package)"/*/ ./document/static/ || true

  # symlink init.js to index.js
  find . -name init.js | while read f; do
    d=$(dirname "$f");
    if [ -f "$d/index.js" ]; then echo "skipping $f"; continue; fi;
    echo "adding $d";
    ln -sv init.js $d/index.js;
  done

  # Uncaught ReferenceError: gettext is not defined
  # see fiduswriter/fiduswriter/document/management/commands/export_schema.py
  # prepend "var gettext = ..." before first line
  echo -e '\nadding mock for gettext'
  sed -i.bak '1s;^;var gettext = () => undefined\n\n;' document/static/js/modules/*/*.js
  sed -i.bak '1s;^;var gettext = () => undefined\n\n;' document/static/js/modules/*/*/*.js
  sed -i.bak '1s;^;var gettext = () => undefined\n\n;' document/static/js/modules/*/*/*/*.js
)

if [ -n "$(find node_modules/citeproc-plus -name '*.csljson')" ]; then

# in project root
# fix unknown file extension csljson
# no idea how to tell vite/rollup to use a "file-loader" for csljson files
# as suggested for webpack at https://github.com/fiduswriter/citeproc-plus

echo -e '\nmoving files: *.csljson -> *.csl.json'
mmv \
  'node_modules/citeproc-plus/dist/assets/*.csljson' \
  'node_modules/citeproc-plus/dist/assets/#1.csl.json'

sed -i.bak -E 's|assets/([^"]+)\.csljson"|assets/\1.csl.json"|g' \
  node_modules/citeproc-plus/dist/*.js \
  node_modules/citeproc-plus/dist/*/*.js

fi
