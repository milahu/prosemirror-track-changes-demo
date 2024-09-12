{ pkgs ? import <nixpkgs> { }
}:

pkgs.mkShell {
  buildInputs = with pkgs; [
    gettext
    (python3.withPackages (pp: with pp; [
      /*
        cat github.com/fiduswriter/fiduswriter/fiduswriter/requirements.txt |
        grep -v '^#' |
        sed 's/==.*''//' |
        tr . _ |
        tr '[[:upper:]]' '[[:lower:]]'
      */
      bleach
      django
      django-allauth
      # see also https://github.com/milahu/nur-packages
      #django-avatar
      (callPackage ./nix/pkgs/python3/pkgs/django-avatar { })
      #django-js-error-hook
      (callPackage ./nix/pkgs/python3/pkgs/django-js-error-hook { })
      #django-npm-mjs
      (callPackage ./nix/pkgs/python3/pkgs/django-npm-mjs { })
      #django-loginas
      (callPackage ./nix/pkgs/python3/pkgs/django-loginas { })
      pillow
      python-dateutil
      python-magic
      #prosemirror
      (callPackage ./nix/pkgs/python3/pkgs/prosemirror { })
      jsonpatch
      httpx
      channels
      daphne
      #django-channels-presence-4_0
      (callPackage ./nix/pkgs/python3/pkgs/django-channels-presence-4_0 { })
    ]))
  ];
}
