{ dosbox-x }:

dosbox-x.overrideAttrs (final: prev: {
  pname = "dosbox-record-replay";
  patches = prev.patches ++ [ ./add-record-replay.patch ];
})
