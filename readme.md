# Features

* Using [mpv](https://github.com/mpv-player/mpv)
* NowPlaying
* No useless features (no features)
* Album shuffle
* LastFM

# TODO

- When I feel like it, implement a way to react to changes in directories.
- Error handling in playback

# Building
1. Build libmpv.
```sh
git clone https://github.com/mpv-player/mpv.git && cd mpv
meson setup build
# configure desired build flags. 
# libmpv flag MUST be enabled!!
meson compile -C build
cd ..
./get_libs.rb "$(brew --prefix)" mpv/build/libmpv.2.dylib # Thanks! https://github.com/iina/iina/blob/develop/other/change_lib_dependencies.rb
```
2. Copy `client.h` to `deps/include/mpv/`.
3. Open Xcode
4. Remove references to `.dylib` files
5. Add `.dylib` files from `deps/include/mpv/` to the project
6. Go to "Build Phases" of the target and add the `.dylib` files to "Copy Dylibs"
7. Build

# Credits

- [IINA](https://github.com/iina/iina)
- [mpv](https://github.com/mpv-player/mpv)
