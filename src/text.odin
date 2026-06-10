package main

// Manual number-to-string formatting used instead of rl.TextFormat.
// On WebKit/Safari rl.TextFormat goes through core:fmt and leaks per call.

@(private = "file")
fmt_bufs: [8][64]u8
@(private = "file")
fmt_idx: int

@(private = "file")
take_buf :: proc() -> []u8 {
	b := fmt_bufs[fmt_idx][:]
	fmt_idx = (fmt_idx + 1) % len(fmt_bufs)
	return b
}

@(private = "file")
put_str :: proc(buf: []u8, pos: int, s: string) -> int {
	p := pos
	for i in 0 ..< len(s) {
		buf[p] = s[i]
		p += 1
	}
	return p
}

@(private = "file")
put_uint :: proc(buf: []u8, pos: int, value: i32, pad: int) -> int {
	v := value
	if v < 0 {
		v = 0
	}
	tmp: [16]u8
	n := 0
	for {
		tmp[n] = u8('0' + (v % 10))
		v /= 10
		n += 1
		if v == 0 {
			break
		}
	}
	p := pos
	for _ in 0 ..< (pad - n) {
		buf[p] = '0'
		p += 1
	}
	for i := n - 1; i >= 0; i -= 1 {
		buf[p] = tmp[i]
		p += 1
	}
	return p
}

// "<prefix><value>", e.g. fmt_int("£", 120) -> "£120"
fmt_int :: proc(prefix: string, value: i32) -> cstring {
	buf := take_buf()
	p := put_str(buf, 0, prefix)
	p = put_uint(buf, p, value, 1)
	buf[p] = 0
	return cstring(raw_data(buf))
}

// "<prefix>MM:SS", e.g. fmt_time("Time: ", 1, 5) -> "Time: 01:05"
fmt_time :: proc(prefix: string, minutes, seconds: i32) -> cstring {
	buf := take_buf()
	p := put_str(buf, 0, prefix)
	p = put_uint(buf, p, minutes, 2)
	buf[p] = ':'
	p += 1
	p = put_uint(buf, p, seconds, 2)
	buf[p] = 0
	return cstring(raw_data(buf))
}
