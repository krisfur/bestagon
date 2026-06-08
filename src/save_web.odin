#+build js
package main

// Web persistence via the browser's localStorage. Save_Data is a small, fixed
// POD struct (no pointers), so it's stored as a hex string of its raw bytes.

import "core:mem"

@(default_calling_convention = "c")
foreign _ {
	emscripten_run_script :: proc(script: cstring) ---
	emscripten_run_script_string :: proc(script: cstring) -> cstring ---
}

@(private = "file")
SAVE_KEY :: "bestagon_save"

load_save_data :: proc() -> Save_Data {
	stored := emscripten_run_script_string("localStorage.getItem('" + SAVE_KEY + "')||''")
	s := string(stored)
	if len(s) != size_of(Save_Data) * 2 {
		return Save_Data{}
	}

	save: Save_Data
	bytes := mem.byte_slice(&save, size_of(Save_Data))
	for i in 0 ..< size_of(Save_Data) {
		hi, hi_ok := hex_value(s[i * 2])
		lo, lo_ok := hex_value(s[i * 2 + 1])
		if !hi_ok || !lo_ok {
			return Save_Data{}
		}
		bytes[i] = hi << 4 | lo
	}

	if save.total_currency < 0 {
		save.total_currency = 0
	}
	return save
}

save_progress :: proc(gs: ^Game_State) {
	save := build_save_data(gs)
	bytes := mem.byte_slice(&save, size_of(Save_Data))

	hex := "0123456789abcdef"

	// Assemble: localStorage.setItem('bestagon_save','<hex>')
	buf: [size_of(Save_Data) * 2 + 64]u8
	n := 0
	n += put(buf[:], n, "localStorage.setItem('" + SAVE_KEY + "','")
	for b in bytes {
		buf[n] = hex[b >> 4]
		buf[n + 1] = hex[b & 0xf]
		n += 2
	}
	n += put(buf[:], n, "')")
	buf[n] = 0 // null terminator for the cstring

	emscripten_run_script(cstring(raw_data(buf[:])))
}

@(private = "file")
put :: proc(buf: []u8, at: int, s: string) -> int {
	for i in 0 ..< len(s) {
		buf[at + i] = s[i]
	}
	return len(s)
}

@(private = "file")
hex_value :: proc(c: u8) -> (u8, bool) {
	switch c {
	case '0' ..= '9':
		return c - '0', true
	case 'a' ..= 'f':
		return c - 'a' + 10, true
	case 'A' ..= 'F':
		return c - 'A' + 10, true
	}
	return 0, false
}
