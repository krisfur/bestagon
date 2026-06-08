#!/bin/bash -eu

# Builds the web (wasm) version of the game with emscripten.
# Requires `emcc` on PATH (e.g. `brew install emscripten`).

OUT_DIR="build/web"
mkdir -p "$OUT_DIR"

# RAYLIB_WASM_LIB / RAYGUI_WASM_LIB point at env.o, a placeholder import label.
# The real raylib symbols come from the vendored libraylib.a fed to emcc below.
odin build src \
	-target:js_wasm32 \
	-build-mode:obj \
	-define:RAYLIB_WASM_LIB=env.o \
	-define:RAYGUI_WASM_LIB=env.o \
	-vet \
	-out:"$OUT_DIR/game.wasm.o"

ODIN_PATH=$(odin root)
cp "$ODIN_PATH/core/sys/wasm/js/odin.js" "$OUT_DIR"

files="$OUT_DIR/game.wasm.o libs/web/libraylib.a"

# Emscripten's default wasm stack is only 64KB; Game_State is ~60KB and is built
# by value at init, so the stack needs raising. Allow memory growth too.
flags="-sEXPORTED_RUNTIME_METHODS=['HEAPF32'] -sUSE_GLFW=3 -sWASM_BIGINT -sWARN_ON_UNDEFINED_SYMBOLS=0 -sASSERTIONS -sSTACK_SIZE=4MB -sALLOW_MEMORY_GROWTH=1 --shell-file web/index_template.html"

# Add `-g` to emcc for better stack traces while debugging.
emcc -o "$OUT_DIR/index.html" $files $flags

rm "$OUT_DIR/game.wasm.o"

echo "Web build created in ${OUT_DIR}. Serve it with run_web.sh"
