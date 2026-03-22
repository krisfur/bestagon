package main

import rl "vendor:raylib"

game_canvas: rl.RenderTexture2D

init_game_canvas :: proc() {
	game_canvas = rl.LoadRenderTexture(LOGICAL_WIDTH, LOGICAL_HEIGHT)
}

unload_game_canvas :: proc() {
	rl.UnloadRenderTexture(game_canvas)
}

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Bestagon")
	defer rl.CloseWindow()
	init_game_canvas()
	defer unload_game_canvas()
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
