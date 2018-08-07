{ stdenv, fetchurl, dpkg
, alsaLib, atk, cairo, cups, curl, dbus, expat, fontconfig, freetype, gdk_pixbuf, glib, glibc, gnome2, gnome3
, gtk3, libnotify, libpulseaudio, libsecret, libv4l, nspr, nss, pango, systemd, wrapGAppsHook, xorg }:

let

  # Please keep the version x.y.0.z and do not update to x.y.76.z because the
  # source of the latter disappears much faster.
  version = "8.24.0.2";

  rpath = stdenv.lib.makeLibraryPath [
    alsaLib
    atk
    cairo
    cups
    curl
    dbus
    expat
    fontconfig
    freetype
    glib
    glibc
    libsecret

    gnome2.GConf
    gdk_pixbuf
    gtk3

    gnome3.gnome-keyring

    libnotify
    libpulseaudio
    nspr
    nss
    pango
    stdenv.cc.cc
    systemd
    libv4l

    xorg.libxkbfile
    xorg.libX11
    xorg.libXcomposite
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXi
    xorg.libXrandr
    xorg.libXrender
    xorg.libXtst
    xorg.libXScrnSaver
    xorg.libxcb
  ] + ":${stdenv.cc.cc.lib}/lib64";

  src =
    if stdenv.system == "x86_64-linux" then
      fetchurl {
        url = "https://repo.skype.com/deb/pool/main/s/skypeforlinux/skypeforlinux_${version}_amd64.deb";
        sha256 = "079bv0wilwwd9gqykcyfs4bj8za140788dxi058k4275h1jlvrww";
      }
    else
      throw "Skype for linux is not supported on ${stdenv.system}";

in stdenv.mkDerivation {
  name = "skypeforlinux-${version}";

  system = "x86_64-linux";

  inherit src;

  nativeBuildInputs = [
    wrapGAppsHook
    glib # For setup hook populating GSETTINGS_SCHEMA_PATH
  ];

  buildInputs = [ dpkg ];

  unpackPhase = "true";
  installPhase = ''
    mkdir -p $out
    dpkg -x $src $out
    cp -av $out/usr/* $out
    rm -rf $out/opt $out/usr
    rm $out/bin/skypeforlinux

    # Otherwise it looks "suspicious"
    chmod -R g-w $out
  '';

  postFixup = ''
    for file in $(find $out -type f \( -perm /0111 -o -name \*.so\* -or -name \*.node\* \) ); do
      patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$file" || true
      patchelf --set-rpath ${rpath}:$out/share/skypeforlinux $file || true
    done

    ln -s "$out/share/skypeforlinux/skypeforlinux" "$out/bin/skypeforlinux"

    wrapProgram $out/bin/skypeforlinux \
      --suffix XDG_DATA_DIRS : "$GSETTINGS_SCHEMAS_PATH"


    # Fix the desktop link
    substituteInPlace $out/share/applications/skypeforlinux.desktop \
      --replace /usr/bin/ $out/bin/ \
      --replace /usr/share/ $out/share/
  '';

  meta = with stdenv.lib; {
    description = "Linux client for skype";
    homepage = https://www.skype.com;
    license = licenses.unfree;
    maintainers = with stdenv.lib.maintainers; [ panaeon jraygauthier ];
    platforms = [ "x86_64-linux" ];
  };
}
