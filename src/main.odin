package main

import rl "vendor:raylib"

game_canvas: rl.RenderTexture2D
game_state: Game_State

init_game_canvas :: proc() {
	game_canvas = rl.LoadRenderTexture(LOGICAL_WIDTH, LOGICAL_HEIGHT)
}

unload_game_canvas :: proc() {
	rl.UnloadRenderTexture(game_canvas)
}

game_init :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .MSAA_4X_HINT})
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Bestagon")
	init_game_canvas()
	rl.HideCursor()
	rl.SetExitKey(.KEY_NULL)

	// On web the browser drives the frame rate via requestAnimationFrame.
	when ODIN_OS != .JS {
		rl.SetTargetFPS(60)
	}

	game_state = create_game_state()
	apply_save_data(&game_state, load_save_data())
}

// Advances the game by one frame. Returns true when the game wants to quit.
game_step :: proc() -> bool {
	if update_game(&game_state) {
		return true
	}
	draw_game(&game_state)
	return false
}

game_shutdown :: proc() {
	save_progress(&game_state)
	unload_game_canvas()
	rl.CloseWindow()
}

// WASM version uses web.odin, not this main entry point.
when ODIN_OS != .JS {
	main :: proc() {
		game_init()
		for !rl.WindowShouldClose() {
			if game_step() {
				break
			}
		}
		game_shutdown()
	}
}
