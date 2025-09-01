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
  libselinux,
  libdnf
}:

python3Full.pkgs.buildPythonApplication rec {
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
  ];

  buildInputs = [
    python3Full
    dracut
    squashfsTools
    cpio
    findutils
    xorriso
    libdnf
    libselinux
  ];

  # Ajout des variables d'environnement pour que Python trouve les bindings
  preBuild = ''
    export PYTHONPATH="${libdnf}/lib/python${python3Full.pythonVersion}/site-packages:$PYTHONPATH"
    export PKG_CONFIG_PATH="${libdnf}/lib/pkgconfig:${libselinux}/lib/pkgconfig:$PKG_CONFIG_PATH"
  '';

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
    
    # Gestion de selinux (optionnel dans Nix)
    substituteInPlace src/pylorax/__init__.py \
      --replace "import selinux" "try: import selinux\nexcept ImportError: selinux = None"
    
    # Correction pour libdnf - utiliser la version système
    substituteInPlace src/pylorax/__init__.py \
      --replace "import libdnf5 as dnf5" "import libdnf as dnf5"
  '';
  
  postFixup = ''
    # Wrapper avec tous les chemins nécessaires
    for prog in $out/bin/*; do
      wrapProgram "$prog" \
        --prefix PATH : ${lib.makeBinPath [ 
          dracut 
          cpio 
          findutils 
          xorriso 
          squashfsTools 
          python3Full 
        ]} \
        --prefix PYTHONPATH : "${libdnf}/lib/python${python3Full.pythonVersion}/site-packages" \
        --set-default LIBDNF_PYTHON_PATH "${libdnf}/lib/python${python3Full.pythonVersion}/site-packages"
    done
  '';

  # Test basique pour vérifier que l'import fonctionne
  checkPhase = ''
    cd $out
    python -c "
    import sys
    sys.path.insert(0, '${libdnf}/lib/python${python3Full.pythonVersion}/site-packages')
    try:
        import libdnf
        print('libdnf imported successfully')
    except ImportError as e:
        print(f'Failed to import libdnf: {e}')
        sys.exit(1)
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