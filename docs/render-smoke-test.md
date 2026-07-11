# Verifying the render boundary

`edm-engine/render` can't be FiveAM-tested (it's the I/O boundary by
design), and `libraylib.so` isn't present in most sandboxes by default.
This is the only way to actually confirm it runs rather than merely
compiles.

## Setup (Ubuntu/Debian)

```sh
sudo apt-get install -y cmake build-essential git libgl1-mesa-dev \
  libx11-dev libxrandr-dev libxi-dev libxcursor-dev libxinerama-dev \
  libwayland-dev libxkbcommon-dev xvfb mesa-utils

git clone --depth 1 https://github.com/raysan5/raylib.git /tmp/raylib
cd /tmp/raylib && mkdir build && cd build
cmake -DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=Release ..
make -j"$(nproc)" raylib
sudo make install && sudo ldconfig
```

## Run headless via Xvfb

Background processes started in one shell don't survive if that shell
exits — use `setsid ... &` with all three fds redirected, not a bare `&`.

```sh
setsid Xvfb :99 -screen 0 1024x768x24 > /tmp/xvfb.log 2>&1 < /dev/null &
sleep 2
export DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1
```

## Smoke test

```sh
sbcl --non-interactive \
  --eval '(ql:quickload :edm-engine/render)' \
  --eval '(edm-engine:open-window "smoke test" 400 300)' \
  --eval '(let ((a (edm-engine:make-arena 4)))
            (edm-engine::arena-spawn a)
            (edm-engine:arena-set-position a (edm-engine::handle 0 0) 200.0 150.0)
            (edm-engine:draw-arena a)
            (raylib:take-screenshot "render-smoke.png"))' \
  --eval '(edm-engine:close-window)'
```

`render-smoke.png` should show a black background with one green filled
circle at (200, 150). Colors are plain keywords (`:black`, `:green`),
not `raylib:+black+`-style constants — that mistake shipped uncaught
until this smoke test actually ran the code.

## Regenerating shaders from c-mera source

`shaders/*.fs`/`*.vs` are generated output, not hand-edited, and are
gitignored — they don't ship in the repo. Running `tools/build-shaders.lisp`
is a required step before the arcade will load, not an optional
regeneration. The source
of truth is `shaders/*.fs.lisp`/`*.vs.lisp` — c-mera GLSL S-expressions,
so state-to-color mappings and other shader logic get the same macro
system as the rest of the engine, not raw string-templated GLSL.

```sh
git clone https://github.com/kiselgra/c-mera.git ~/quicklisp/local-projects/c-mera
sbcl --non-interactive --load ~/quicklisp/setup.lisp --load tools/build-shaders.lisp
```

c-mera isn't on Quicklisp or Ultralisp — clone it into `local-projects`.
Its own CLI (`roswell/cm.ros`) parses argv via `net.didierverna.clon`,
which only works against a real process argv; it silently reports
"No input specified" when driven programmatically. `tools/build-shaders.lisp`
instead calls c-mera's read/traverse/pretty-print pipeline directly,
bypassing the CLI layer. It also prepends `#version 330` itself — c-mera's
GLSL backend has no node for preprocessor pragmas, so that line is the
build script's job, not the DSL's.
