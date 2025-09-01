{ lib,
  python3Full,
  fetchgit,
  dracut,
  squashfsTools,
  cpio,
  findutils,
  xorriso,
  makeWrapper,
  pkg-config,
  libdnf,
  cmake,
  swig,
  glib,
  json-glib,
  libmodulemd,
  librepo,
  libsolv,
  openssl,
  sqlite,
  zchunk,
  zlib
}:

let
  # Construire les bindings Python pour libdnf
  python-libdnf = python3Full.pkgs.buildPythonPackage rec {
    pname = "libdnf-python";
    version = libdnf.version;
    
    pyproject = true;
    build-system = with python3Full.pkgs; [ setuptools ];

    src = libdnf.src;
    
    nativeBuildInputs = [
      cmake
      pkg-config
      swig
      python3Full
    ];
    
    buildInputs = [
      libdnf
      glib
      json-glib
      libmodulemd
      librepo
      libsolv
      openssl
      sqlite
      zchunk
      zlib
    ];
    
    dontUseCmakeConfigure = false;
    
    cmakeFlags = [
      "-DPYTHON_DESIRED=${python3Full.pythonVersion}"
      "-DWITH_BINDINGS=ON"
      "-DPYTHON_EXECUTABLE=${python3Full}/bin/python"
    ];
    
    # Ne construire que les bindings Python
    buildPhase = ''
      cd bindings/python
      make -j$NIX_BUILD_CORES
    '';
    
    installPhase = ''
      cd bindings/python
      make install
      mkdir -p $out/${python3Full.sitePackages}
      cp -r $out/lib/python*/site-packages/* $out/${python3Full.sitePackages}/ || true
    '';
  };

in python3Full.pkgs.buildPythonApplication rec {
  pname = "lorax";
  version = "43.10-1";

  pyproject = true;
  build-system = with python3Full.pkgs; [ setuptools ];

  nativeBuildInputs = [
    makeWrapper
    pkg-config
    python3Full
  ] ++ (with python3Full.pkgs; [
    setuptools
    pip
    wheel
  ]);

  src = fetchgit {
    url = "https://github.com/weldr/lorax.git";
    rev = "lorax-${version}";
    sha256 = "055f243chlvb529d60dcj4nw5mmbjm27jvalhsz7rc9l6i340prn";
  };

  dependencies = with python3Full.pkgs; [
    pyparted
    requests
    python-libdnf
  ];

  buildInputs = [
    python3Full
    dracut
    squashfsTools
    cpio
    findutils
    xorriso
    libdnf
  ];

  postPatch = ''
    # Correction des chemins vers dracut
    substituteInPlace src/pylorax/dnfhelper.py \
      --replace "/usr/bin/dracut" "${dracut}/bin/dracut"
    
    # Corrections pour les autres outils système
    find . -name "*.py" -exec sed -i \
      -e 's|/usr/bin/cpio|${cpio}/bin/cpio|g' \
      -e 's|/usr/bin/find|${findutils}/bin/find|g' \
      -e 's|/usr/bin/xorriso|${xorriso}/bin/xorriso|g' \
      -e 's|/usr/bin/mksquashfs|${squashfsTools}/bin/mksquashfs|g' \
      {} \;
    
    # Gestion de selinux (mock pour Nix)
    substituteInPlace src/pylorax/__init__.py \
      --replace "import selinux" "selinux = type('MockSelinux', (), {'is_selinux_enabled': lambda: False, 'getcon': lambda: ('system_u', 'system_r', 'unconfined_t', 's0')})()"
    
    # Garder libdnf tel quel car nous avons maintenant les bindings
    # substituteInPlace src/pylorax/__init__.py \
    #   --replace "import libdnf5 as dnf5" "import libdnf as dnf5"
  '';
  
  postFixup = ''
    for prog in $out/bin/*; do
      wrapProgram "$prog" \
        --prefix PATH : ${lib.makeBinPath [ 
          dracut 
          cpio 
          findutils 
          xorriso 
          squashfsTools 
          python3Full 
        ]}
    done
  '';

  # Test pour vérifier les imports
  doCheck = false; # Désactivé par défaut car peut être fragile
  checkPhase = ''
    python -c "
    try:
        import libdnf
        print('libdnf imported successfully')
    except ImportError as e:
        print(f'Failed to import libdnf: {e}')
        exit(1)
    "
  '';

  meta = with lib; {
    description = "Set of tools to create bootable images";
    homepage = "https://github.com/weldr/lorax";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
    maintainers = with maintainers; [ fkozmik ];
  };
}