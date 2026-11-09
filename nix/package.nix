{
  lib,
  stdenvNoCC,
  makeWrapper,
  quickshell,
  bash,
  cliphist,
  libqalculate,
  libnotify,
  pipewire,
  sound-theme-freedesktop,
  coreutils,
  systemd,
  util-linux,
  wl-clipboard,
  wtype,
  wlsunset,
  ddcutil,
}:

stdenvNoCC.mkDerivation {
  pname = "okaeri";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../bin
      ../shell
    ];
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/okaeri
    cp -r shell $out/share/okaeri/shell
    install -Dm755 bin/okaeri $out/libexec/okaeri
    makeWrapper $out/libexec/okaeri $out/bin/okaeri \
      --set-default OKAERI_SHELL_DIR $out/share/okaeri/shell \
      --prefix PATH : ${
        lib.makeBinPath [
          quickshell
          bash
          cliphist
          libqalculate
          libnotify
          pipewire
          coreutils
          systemd
          util-linux
          wl-clipboard
          wtype
          wlsunset
          ddcutil
        ]
      } \
      --suffix XDG_DATA_DIRS : ${sound-theme-freedesktop}/share

    runHook postInstall
  '';

  meta = {
    description = "A desktop shell for niri on Quickshell";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "okaeri";
  };
}
