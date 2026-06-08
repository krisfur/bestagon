#+build js
package main

import "base:runtime"
import "core:c"
import rl "vendor:raylib"

// On web the game loop fps is driven by requestAnimationFrame
FRAME_TIME :: 1.0 / 60.0

@(private = "file")
web_context: runtime.Context
@(private = "file")
prev_time: f64
@(private = "file")
accumulator: f64

@(export)
main_start :: proc "c" () {
	context = runtime.default_context()
	web_context = context
	game_init()
	prev_time = rl.GetTime()
}

@(export)
main_update :: proc "c" () -> bool {
	context = web_context

	now := rl.GetTime()
	accumulator += now - prev_time
	prev_time = now

	if accumulator < FRAME_TIME {
		return true
	}
	// Drop any large backlog (e.g. after the tab was backgrounded)
	// the game resumes rather than fast-forwarding.
	if accumulator > 4 * FRAME_TIME {
		accumulator = FRAME_TIME
	}
	accumulator -= FRAME_TIME

	return !game_step()
}

@(export)
main_end :: proc "c" () {
	context = web_context
	game_shutdown()
}

@(export)
web_window_size_changed :: proc "c" (w, h: c.int) {
	context = web_context
	rl.SetWindowSize(w, h)
}
