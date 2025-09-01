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
 libdnf  # <- utilisons libdnf v4 en attendant
}:

python3Full.pkgs.buildPythonApplication rec {
  pname = "lorax";
  version = "lorax-43.10-1";

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
    rev = "v${version}";
    sha256 = "055f243chlvb529d60dcj4nw5mmbjm27jvalhsz7rc9l6i340prn";
  };

  dependencies = with python3Full.pkgs; [
    pyparted
    requests
    libdnf
    # libselinux
  ];

  buildInputs = [
    python3Full
    dracut
    squashfsTools
    cpio
    findutils
    xorriso
  ];

  postPatch = ''
    substituteInPlace src/pylorax/dnfhelper.py \
      --replace "/usr/bin/dracut" "${dracut}/bin/dracut"
    
    # Mock selinux
    substituteInPlace src/pylorax/__init__.py \
      --replace "import selinux" "selinux = None"
    find . -name "*.py" -exec sed -i 's/import selinux/selinux = None  # Disabled/g' {} \;
    
    substituteInPlace src/pylorax/__init__.py \
      --replace "import libdnf5 as dnf5" "import libdnf as dnf5"
  '';
  
  postFixup = ''
    wrapProgram $out/bin/lorax \
      --prefix PATH : ${python3Full}/bin
  '';

  meta = with lib; {
    description = "Set of tools to create bootable images";
    homepage = "https://github.com/weldr/lorax";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
    maintainers = with maintainers; [ fkozmik ];
  };
}
