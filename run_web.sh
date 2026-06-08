#!/bin/bash -eu

# Uses Python's stdlib server (zero deps) with the correct wasm MIME type.
#
# Usage: ./run_web.sh [port]   (default port 8080)

PORT="${1:-8080}"
DIR="build/web"

if [ ! -f "$DIR/index.html" ]; then
	echo "No web build found, running build_web.sh ..."
	./build_web.sh
fi

exec python3 -u - "$DIR" "$PORT" <<'PY'
import functools, http.server, socketserver, sys

directory, port = sys.argv[1], int(sys.argv[2])

# instantiateStreaming() requires the exact wasm MIME type
http.server.SimpleHTTPRequestHandler.extensions_map.update({
	".wasm": "application/wasm",
	".js": "text/javascript",
})
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=directory)


try:
	httpd = socketserver.TCPServer(("127.0.0.1", port), handler)
except OSError:
	sys.exit(f"Port 8080 busy.")
print(f"Serving {directory} at http://localhost:{port}/  (Ctrl-C to stop)")
try:
	httpd.serve_forever()
except KeyboardInterrupt:
	print()
finally:
	httpd.server_close()
PY
