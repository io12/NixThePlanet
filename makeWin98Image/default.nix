# https://dosbox-x.com/wiki/Guide%3AInstalling-Windows-98#_installation_method_2

{ lib, fetchurl, runCommand, p7zip, dosbox-record-replay, xvfb-run, x11vnc
, tesseract, expect, vncdo, imagemagick, writeScript, writeShellScript
, writeText, fetchFromGitHub, callPackage, rustPlatform, pkg-config, libunwind
}:
{ dosPostInstall ? "", ... }:
let
  win98-installer = fetchurl {
    name = "win98.7z";
    urls = [
      "https://winworldpc.com/download/c3b4c382-3210-e280-9d7b-11c3a4c2ac5a/from/c39ac2af-c381-c2bf-1b25-11c3a4e284a2"
      "https://winworldpc.com/download/c3b4c382-3210-e280-9d7b-11c3a4c2ac5a/from/c3ae6ee2-8099-713d-3411-c3a6e280947e"
      "https://cloudflare-ipfs.com/ipfs/QmTTNMpQALDzioSNdDJyr94rkz5tHoAHCDa155fvHyJb4L/Microsoft%20Windows%2098%20Second%20Edition%20(4.10.2222)%20(Retail%20Full).7z"
    ];
    hash = "sha256-47M3azg2ikc7VlFTEJA7elPGovAtSmhOtZqq8j2TJmU=";
  };
  dosboxConf = writeText "dosbox.conf" ''
    [cpu]
    turbo = on
    stop turbo on key = false

    [autoexec]
    if exist win98.img (
      imgmount c win98.img
      boot c:
    ) else (
      imgmake win98.img -t hd_520
      imgmount c win98.img -t hdd -fs fat
      imgmount d win98.iso
      xcopy d:\win98 c:\win98 /i /e
      c:
      cd \win98
      setup
    )
  '';
  tesseractScript = writeShellScript "tesseractScript" ''
    export OMP_THREAD_LIMIT=1
    cd $(mktemp -d)
    TEXT=""
    while true
    do
      sleep 3
      ${vncdo}/bin/vncdo -s 127.0.0.1::5900 capture cap-small.png
      ${imagemagick}/bin/convert cap-small.png -interpolate Integer -filter point -resize 400% cap.png
      NEW_TEXT="$(${tesseract}/bin/tesseract cap.png stdout 2>/dev/null)"
      echo "$NEW_TEXT"
      TEXT="$NEW_TEXT"
    done
  '';
  iso = runCommand "win98.iso" { } ''
    echo "win98-installer src: ${win98-installer}"
    mkdir win98
    ${p7zip}/bin/7z x -owin98 ${win98-installer}
    ls -lah win98
    mv win98/*.iso $out
  '';
  hermit = rustPlatform.buildRustPackage {
    name = "hermit";
    src = fetchFromGitHub {
      owner = "facebookexperimental";
      repo = "hermit";
      rev = "166215be090dd584abd55bbe60cd08a5935374bf";
      hash = "sha256-hTtluyIOGPKK/ruFU46xTZ1mIaoL363XoerMajofa40=";
    };
    postPatch = "cp ${./Cargo.lock} Cargo.lock";
    cargoLock = {
      lockFile = ./Cargo.lock;
      outputHashes = {
        "fbinit-0.1.2" = "sha256-jvMvaUN8TzcDle2F0ucpiAhZmtwEDd7LWVtJvhn7GwU=";
        "reverie-0.1.0" = "sha256-cNYALcZs1D+3Chkl57DFUkTBBTkSibjQ+wQBYl4lVAk=";
      };
    };
    nativeBuildInputs = [ pkg-config ];
    buildInputs = [ libunwind ];
    RUSTC_BOOTSTRAP = 1;
    doCheck = false;
  };
  installedImage = runCommand "win98.img" {
    # set __impure = true; for debugging
    # __impure = true;
    buildInputs = [ p7zip dosbox-record-replay xvfb-run x11vnc hermit ];
    passthru = rec {
      makeRunScript = callPackage ./run.nix;
      runScript = makeRunScript { };
    };
  } ''
    echo "iso src: ${iso}"
    cp --no-preserve=mode ${iso} win98.iso
    (
      while true; do
        DISPLAY=:99 XAUTHORITY=/tmp/xvfb.auth x11vnc -many -shared -display :99 >/dev/null 2>&1 || true
        echo RESTARTING VNC
      done
    ) &
    ${tesseractScript} &
    runDosbox() {
      xvfb-run -l -s ":99 -auth /tmp/xvfb.auth -ac -screen 0 800x600x24" hermit run -- ${dosbox-record-replay}/bin/dosbox-x -conf ${dosboxConf} || true &
      dosboxPID=$!
    }
    echo STAGE 1
    cp -f ${./input-recordings/stage-1.txt} input-recording.txt
    runDosbox
    wait $dosboxPID
    # Run dosbox-x a second time since it exits during the install
    echo STAGE 2
    cp -f ${./input-recordings/stage-2.txt} input-recording.txt
    runDosbox
    wait $dosboxPID
    echo DOSBOX EXITED
    cp win98.img $out
  '';
  postInstalledImage = let
    dosboxConf-postInstall = writeText "dosbox.conf" ''
      [cpu]
      turbo=on
      stop turbo on key = false

      [autoexec]
      imgmount c win98.img
      ${dosPostInstall}
      exit
    '';
  in runCommand "win98.img" {
    buildInputs = [ dosbox-record-replay ];
    inherit (installedImage) passthru;
  } ''
    cp --no-preserve=mode ${installedImage} ./win98.img
    SDL_VIDEODRIVER=dummy dosbox-x -conf ${dosboxConf-postInstall}
    mv win98.img $out
  '';
in iso # if (dosPostInstall != "") then postInstalledImage else installedImage
