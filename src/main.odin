package main

import rl "vendor:raylib"

main :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Bestagon")
	defer rl.CloseWindow()
	rl.HideCursor()

	rl.SetTargetFPS(60)
	rl.SetExitKey(.KEY_NULL)

	game_state := create_game_state()
	apply_save_data(&game_state, load_save_data())

	for !rl.WindowShouldClose() {
		if update_game(&game_state) {
			break
		}
		draw_game(&game_state)
	}

	save_progress(&game_state)
}
