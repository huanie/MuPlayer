#!/usr/bin/env bash

OUT=target/MusicPlayerFFI.xcframework
rm -rf "${OUT}"
cargo build -r

xcodebuild -create-xcframework \
    -library target/release/libmusic_player_ffi.dylib -headers generated/ \
    -output "${OUT}"
