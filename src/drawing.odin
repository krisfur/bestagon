package main

import "core:math"
import rl "vendor:raylib"

draw_hexagon :: proc(center_x, center_y, radius: f32, color: rl.Color) {
	num_sides := 6
	for i in 0..<num_sides {
		a1 := f32(i) * 2 * math.PI / f32(num_sides)
		a2 := f32(i+1) * 2 * math.PI / f32(num_sides)

		x1 := center_x + radius*math.cos(a1)
		y1 := center_y + radius*math.sin(a1)
		x2 := center_x + radius*math.cos(a2)
		y2 := center_y + radius*math.sin(a2)

		rl.DrawLine(i32(x1), i32(y1), i32(x2), i32(y2), color)
	}
}

draw_star :: proc(center_x, center_y, radius: f32, color: rl.Color) {
	num_points := 5
	for i in 0..<num_points {
		a1 := f32(i) * 2 * math.PI / f32(num_points)
		x1 := center_x + radius*math.cos(a1)
		y1 := center_y + radius*math.sin(a1)

		a2 := a1 + math.PI/f32(num_points)
		x2 := center_x + radius*0.5*math.cos(a2)
		y2 := center_y + radius*0.5*math.sin(a2)

		a3 := f32(i+1) * 2 * math.PI / f32(num_points)
		x3 := center_x + radius*math.cos(a3)
		y3 := center_y + radius*math.sin(a3)

		rl.DrawLine(i32(x1), i32(y1), i32(x2), i32(y2), color)
		rl.DrawLine(i32(x2), i32(y2), i32(x3), i32(y3), color)
	}
}

draw_square :: proc(center_x, center_y, size: f32, color: rl.Color) {
	half := size * 0.5
	rl.DrawRectangle(i32(center_x-half), i32(center_y-half), i32(size), i32(size), color)
}

draw_health_bar :: proc(x, y, width, height, current, max_value: f32, bar_color: rl.Color) {
	rl.DrawRectangleLines(i32(x), i32(y), i32(width), i32(height), rl.BLACK)

	p := current / max_value
	if p < 0 {
		p = 0
	}
	rl.DrawRectangle(i32(x), i32(y), i32(width*p), i32(height), bar_color)
}

enemy_color_to_raylib :: proc(color: Enemy_Color) -> rl.Color {
	switch color {
	case .Red:
		return rl.RED
	case .Blue:
		return rl.SKYBLUE
	case .Green:
		return rl.GREEN
	}
	return rl.RED
}

draw_menu :: proc(gs: ^Game_State, is_game_over: bool) {
	center_x := rl.GetScreenWidth() / 2
	center_y := rl.GetScreenHeight() / 2

	rl.DrawText("BESTAGON", center_x-120, 80, 50, rl.MAGENTA)

	if is_game_over {
		run_complete_text: cstring = "RUN COMPLETE"
		run_complete_w := rl.MeasureText(run_complete_text, 40)
		rl.DrawText(run_complete_text, center_x-run_complete_w/2, center_y-150, 40, rl.RED)

		survived_total_seconds := i32(gs.elapsed_time)
		survived_minutes := survived_total_seconds / 60
		survived_seconds := survived_total_seconds % 60
		survived_text := rl.TextFormat("Survived: %02d:%02d", survived_minutes, survived_seconds)
		survived_w := rl.MeasureText(survived_text, 25)
		rl.DrawText(survived_text, center_x-survived_w/2, center_y-60, 25, rl.WHITE)

		earned_text := rl.TextFormat("Earned: £%d", gs.session_currency)
		earned_w := rl.MeasureText(earned_text, 25)
		rl.DrawText(earned_text, center_x-earned_w/2, center_y-95, 25, rl.GOLD)
	}

	total_text := rl.TextFormat("£%d", gs.total_currency)
	total_w := rl.MeasureText(total_text, 40)
	rl.DrawText(total_text, center_x-total_w/2, center_y-10, 40, rl.GOLD)

	button_y := center_y + 60
	colors := [3]rl.Color{rl.GRAY, rl.GRAY, rl.GRAY}
	colors[gs.menu_selection] = rl.GREEN

	rl.DrawRectangleLines(center_x-100, button_y, 200, 50, colors[0])
	rl.DrawText("FIGHT", center_x-35, button_y+15, 25, colors[0])

	rl.DrawRectangleLines(center_x-100, button_y+70, 200, 50, colors[1])
	upgrades_text: cstring = "UPGRADES"
	upgrades_w := rl.MeasureText(upgrades_text, 25)
	rl.DrawText(upgrades_text, center_x-upgrades_w/2, button_y+85, 25, colors[1])

	rl.DrawRectangleLines(center_x-100, button_y+140, 200, 50, colors[2])
	rl.DrawText("EXIT", center_x-25, button_y+155, 25, colors[2])

	menu_hint: cstring = "W/S or Up/Down to select, Space or Enter to confirm"
	menu_hint_w := rl.MeasureText(menu_hint, 16)
	rl.DrawText(menu_hint, center_x-menu_hint_w/2, rl.GetScreenHeight()-50, 16, rl.WHITE)
}

draw_playing :: proc(gs: ^Game_State) {
	draw_hexagon(gs.player.position.x, gs.player.position.y, gs.player.radius, rl.MAGENTA)

	draw_star(gs.star_red.position.x, gs.star_red.position.y, gs.star_red.radius, rl.RED)
	draw_star(gs.star_blue.position.x, gs.star_blue.position.y, gs.star_blue.radius, rl.SKYBLUE)
	draw_star(gs.star_green.position.x, gs.star_green.position.y, gs.star_green.radius, rl.GREEN)

	for i in 0..<gs.enemy_count {
		enemy := gs.enemies[i]
		color := enemy_color_to_raylib(enemy.color)
		draw_square(enemy.position.x, enemy.position.y, enemy.size, color)

		bar_w := enemy.size
		draw_health_bar(enemy.position.x-bar_w*0.5, enemy.position.y-enemy.size*0.5-15, bar_w, 5, enemy.health, enemy.max_health, rl.LIME)
	}

	bar_w: f32 = 400
	bar_h: f32 = 30
	bar_x := f32(rl.GetScreenWidth())*0.5 - bar_w*0.5
	bar_y: f32 = 50

	draw_health_bar(bar_x, bar_y, bar_w, bar_h, gs.star_power, gs.max_star_power, rl.GOLD)
	star_power_x := i32(bar_x + 10)
	star_power_y := i32(bar_y + 6)
	rl.DrawText("STAR POWER", star_power_x-1, star_power_y, 16, rl.BLACK)
	rl.DrawText("STAR POWER", star_power_x+1, star_power_y, 16, rl.BLACK)
	rl.DrawText("STAR POWER", star_power_x, star_power_y-1, 16, rl.BLACK)
	rl.DrawText("STAR POWER", star_power_x, star_power_y+1, 16, rl.BLACK)
	rl.DrawText("STAR POWER", star_power_x, star_power_y, 16, rl.WHITE)

	rl.DrawText("BESTAGON", 10, 10, 30, rl.GREEN)
	rl.DrawText("WASD or Arrows to move", 10, 90, 20, rl.WHITE)

	elapsed_total_seconds := i32(gs.elapsed_time)
	elapsed_minutes := elapsed_total_seconds / 60
	elapsed_seconds := elapsed_total_seconds % 60
	rl.DrawText(rl.TextFormat("Time: %02d:%02d", elapsed_minutes, elapsed_seconds), 10, rl.GetScreenHeight()-30, 20, rl.WHITE)

	rl.DrawText(rl.TextFormat("£%d", gs.total_currency), rl.GetScreenWidth()-180, 10, 20, rl.GOLD)
	rl.DrawText(rl.TextFormat("Session: £%d", gs.session_currency), rl.GetScreenWidth()-180, 40, 16, rl.RED)
}

draw_paused :: proc(gs: ^Game_State) {
	draw_playing(gs)
	rl.DrawRectangle(0, 0, rl.GetScreenWidth(), rl.GetScreenHeight(), rl.Fade(rl.BLACK, 0.7))

	center_x := rl.GetScreenWidth() / 2
	center_y := rl.GetScreenHeight() / 2

	paused_text: cstring = "PAUSED"
	paused_w := rl.MeasureText(paused_text, 50)
	rl.DrawText(paused_text, center_x-paused_w/2, center_y-100, 50, rl.WHITE)

	colors := [2]rl.Color{rl.GRAY, rl.GRAY}
	colors[gs.pause_selection] = rl.GREEN

	rl.DrawRectangleLines(center_x-100, center_y-20, 200, 50, colors[0])
	continue_text: cstring = "CONTINUE"
	continue_w := rl.MeasureText(continue_text, 25)
	rl.DrawText(continue_text, center_x-continue_w/2, center_y-5, 25, colors[0])

	rl.DrawRectangleLines(center_x-100, center_y+50, 200, 50, colors[1])
	rl.DrawText("EXIT", center_x-25, center_y+65, 25, colors[1])

	pause_hint: cstring = "Press Escape to resume"
	pause_hint_w := rl.MeasureText(pause_hint, 16)
	rl.DrawText(pause_hint, center_x-pause_hint_w/2, center_y+130, 16, rl.WHITE)
}

draw_game :: proc(gs: ^Game_State) {
	rl.BeginDrawing()
	rl.ClearBackground(rl.Color([4]u8{20, 20, 30, 255}))

	switch gs.current_screen {
	case .Menu:
		draw_menu(gs, false)
	case .Game_Over:
		draw_menu(gs, true)
	case .Upgrades:
		draw_upgrades(gs)
	case .Playing:
		draw_playing(gs)
	case .Paused:
		draw_paused(gs)
	}

	rl.EndDrawing()
}
