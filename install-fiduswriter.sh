#!/usr/bin/env bash

#fiduswriter_branch=master
fiduswriter_branch=develop

# ---- config done ----

set -e # fail on errors

which mmv >/dev/null || { echo please install mmv; exit 1; }
which git >/dev/null || { echo please install git; exit 1; }
which sed >/dev/null || { echo please install sed; exit 1; }
which python3 >/dev/null || { echo please install python3; exit 1; }
which pip3 >/dev/null || { echo please install pip3; exit 1; }
#which ncu >/dev/null || { echo please install ncu: npm i -g npm-check-updates; exit 1; }

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

#[ -d node_modules/prosemirror-model ] || { echo please install npm package prosemirror-model; exit 1; }
## fix: looks like multiple versions of prosemirror-model were loaded
## https://github.com/ueberdosis/tiptap/issues/577
#prosemirror_model_version=$(cat node_modules/prosemirror-model/package.json | jq -r .version)

# https://github.com/fiduswriter/fiduswriter/pull/1143
patchfile_path="$(readlink -f patches/fiduswriter-remove-invalid-json-comments.diff)"

# https://github.com/fiduswriter/fiduswriter/pull/1144
patchfile_path_2="$(readlink -f patches/update-prosemirror-model-to-1.14.1.diff)"

mkdir -p $(dirname $fwdir) || true
(
  cd $(dirname $fwdir)
  git clone --depth 1 --branch $fiduswriter_branch https://github.com/fiduswriter/fiduswriter.git
  cd fiduswriter

  patch -p1 --forward --reject-file=- <"$patchfile_path"
  patch -p1 --forward --reject-file=- <"$patchfile_path_2"

  cd fiduswriter

  # REVOKE this is too aggressive -> update-prosemirror-model-to-1.14.1.diff
  false && {
    # update deps
    find . -name package.json \
    | while read package_json
    do
      package_dir=$(dirname "$package_json")
      (
        cd "$package_dir"
        echo "run 'ncu -u' in $(pwd)"
        # 'echo |' otherwise ncu complains about invalid stdin
        echo | ncu --upgrade
      )
    done
    #done < <(find . -name package.json)
  }

  # https://github.com/fiduswriter/fiduswriter/wiki/Installation-for-developers

  cp configuration.py-default configuration.py

  # debian
  which apt >/dev/null && {
    sudo apt install libjpeg-dev python3-dev python3-pip gettext zlib1g-dev git npm nodejs build-essential
    python3 manage.py setup
  }

  # nixos
  which nix-shell >/dev/null && {
    # some python modules are missing in nixpkgs
    cat requirements.txt | grep -v -i -E '(bleach|django|django-allauth|pillow|python-dateutil|python-magic|tornado|jsonpatch)==' >requirements.filtered.txt
    pip3 install -r requirements.filtered.txt

    nix-shell -p gettext python38Packages.{bleach,django,django-allauth} \
      python38Packages.{pillow,python-dateutil,python_magic,tornado,jsonpatch} \
      --run 'python3 manage.py setup'
  }

  # pip on nixos will break python-magic -> install only nixos.python_magic
  #pip3 install -r requirements.txt



  # in fiduswriter/fiduswriter
  # "fix" import paths
  # symlink all files into the document package
  echo -e '\nmerge packages (apply migrations) ...'
  find . -mindepth 2 -name '*.js' | cut -d/ -f2 | uniq \
  | grep -v -e document -e '\.transpile' -e static-libs | while read package
  do
    echo -e "\nmerge $package/ to document/"
    # cp -s needs absolute source path
    cp -asv "$(readlink -f $package)"/*/ ./document/ || true
    # allow to fail: "symbolic link exists"
  done

  package=static-libs
  echo -e "\nmerge $package/ to document/static/"
  cp -asv "$(readlink -f $package)"/*/ ./document/static/ || true

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
