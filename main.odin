package main

import "core:math"
import "core:encoding/json"
import os "core:os/os2"
import rl "vendor:raylib"

WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720
MAX_ENEMIES :: 1024
ENEMY_KILL_REWARD :: i32(20)
SAVE_FILE_NAME :: ".bestagon_save.json"

Enemy_Color :: enum i32 {
	Red,
	Blue,
	Green,
}

Screen :: enum i32 {
	Menu,
	Playing,
	Upgrades,
	Game_Over,
	Paused,
}

Vector2 :: struct {
	x: f32,
	y: f32,
}

Player :: struct {
	position: Vector2,
	velocity: Vector2,
	speed: f32,
	radius: f32,
}

Star :: struct {
	position: Vector2,
	radius: f32,
	speed: f32,
}

Enemy :: struct {
	position: Vector2,
	size: f32,
	health: f32,
	max_health: f32,
	color: Enemy_Color,
}

Game_State :: struct {
	player: Player,
	star_red: Star,
	star_blue: Star,
	star_green: Star,

	enemies: [MAX_ENEMIES]Enemy,
	enemy_count: int,

	star_power: f32,
	max_star_power: f32,
	enemy_spawn_rate: f32,
	spawn_timer: f32,
	base_enemy_health: f32,

	current_screen: Screen,
	menu_selection: int,
	pause_selection: int,
	skill_tree_tab: int,

	score: i32,
	session_currency: i32,
	total_currency: i32,
	elapsed_time: f32,
}

Save_Data :: struct {
	total_currency: i32,
}

save_file_path :: proc() -> string {
	home_dir, err := os.user_home_dir(context.temp_allocator)
	if err != nil {
		return SAVE_FILE_NAME
	}
	parts := [2]string{home_dir, SAVE_FILE_NAME}
	joined, join_err := os.join_path(parts[:], context.temp_allocator)
	if join_err != nil {
		return SAVE_FILE_NAME
	}
	return joined
}

load_total_currency :: proc() -> i32 {
	data, err := os.read_entire_file_from_path(save_file_path(), context.temp_allocator)
	if err != nil {
		return 0
	}

	save := Save_Data{}
	unmarshal_err := json.unmarshal(data, &save)
	if unmarshal_err != nil {
		return 0
	}

	if save.total_currency < 0 {
		return 0
	}

	return save.total_currency
}

save_total_currency :: proc(total_currency: i32) {
	save := Save_Data{total_currency = total_currency}
	json_data, marshal_err := json.marshal(save, json.Marshal_Options{pretty = true}, context.temp_allocator)
	if marshal_err != nil {
		return
	}

	_ = os.write_entire_file_from_bytes(save_file_path(), json_data)
}

distance :: proc(a, b: Vector2) -> f32 {
	dx := a.x - b.x
	dy := a.y - b.y
	return math.sqrt(dx*dx + dy*dy)
}

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

update_player :: proc(player: ^Player) {
	player.velocity = Vector2{0, 0}

	if rl.IsKeyDown(.W) || rl.IsKeyDown(.UP) {
		player.velocity.y -= player.speed
	}
	if rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN) {
		player.velocity.y += player.speed
	}
	if rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT) {
		player.velocity.x -= player.speed
	}
	if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT) {
		player.velocity.x += player.speed
	}

	player.position.x += player.velocity.x
	player.position.y += player.velocity.y

	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())

	if player.position.x-player.radius < 0 {
		player.position.x = player.radius
	}
	if player.position.x+player.radius > sw {
		player.position.x = sw - player.radius
	}
	if player.position.y-player.radius < 0 {
		player.position.y = player.radius
	}
	if player.position.y+player.radius > sh {
		player.position.y = sh - player.radius
	}
}

update_star :: proc(star: ^Star, player_pos, offset: Vector2) {
	target_x := player_pos.x + offset.x
	target_y := player_pos.y + offset.y

	star.position.x += (target_x - star.position.x) * star.speed
	star.position.y += (target_y - star.position.y) * star.speed
}

remove_enemy :: proc(gs: ^Game_State, index: int) {
	if gs.enemy_count <= 0 {
		return
	}
	last := gs.enemy_count - 1
	gs.enemies[index] = gs.enemies[last]
	gs.enemy_count = last
}

spawn_enemy :: proc(gs: ^Game_State) {
	if gs.enemy_count >= MAX_ENEMIES {
		return
	}

	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())

	new_enemy := Enemy{}
	new_enemy.size = 30
	new_enemy.max_health = gs.base_enemy_health
	new_enemy.health = new_enemy.max_health
	new_enemy.color = Enemy_Color(rl.GetRandomValue(0, 2))

	edge := rl.GetRandomValue(0, 3)
	switch edge {
	case 0:
		new_enemy.position.x = f32(rl.GetRandomValue(0, i32(sw)))
		new_enemy.position.y = -15
	case 1:
		new_enemy.position.x = f32(rl.GetRandomValue(0, i32(sw)))
		new_enemy.position.y = sh + 15
	case 2:
		new_enemy.position.x = -15
		new_enemy.position.y = f32(rl.GetRandomValue(0, i32(sh)))
	case 3:
		new_enemy.position.x = sw + 15
		new_enemy.position.y = f32(rl.GetRandomValue(0, i32(sh)))
	}

	gs.enemies[gs.enemy_count] = new_enemy
	gs.enemy_count += 1
}

update_enemies :: proc(gs: ^Game_State) {
	i := 0
	for i < gs.enemy_count {
		enemy := &gs.enemies[i]
		dx := gs.player.position.x - enemy.position.x
		dy := gs.player.position.y - enemy.position.y
		dist := distance(enemy.position, gs.player.position)

		if dist > 0 {
			speed: f32 = 2.0
			enemy.position.x += (dx / dist) * speed
			enemy.position.y += (dy / dist) * speed
		}

		sw := f32(rl.GetScreenWidth())
		sh := f32(rl.GetScreenHeight())
		if enemy.position.x < -50 || enemy.position.x > sw+50 || enemy.position.y < -50 || enemy.position.y > sh+50 {
			remove_enemy(gs, i)
			continue
		}

		i += 1
	}
}

check_collisions :: proc(gs: ^Game_State) {
	for i in 0..<gs.enemy_count {
		enemy := &gs.enemies[i]
		dist := distance(gs.player.position, enemy.position)
		if dist < gs.player.radius+enemy.size*0.5 {
			dx := gs.player.position.x - enemy.position.x
			dy := gs.player.position.y - enemy.position.y
			bounce_dist: f32 = 50
			bounce_len := math.sqrt(dx*dx + dy*dy)
			if bounce_len > 0 {
				gs.player.position.x += (dx / bounce_len) * bounce_dist
				gs.player.position.y += (dy / bounce_len) * bounce_dist
			}

			gs.star_power -= 5.0 * 0.5 * 60
			if gs.star_power < 0 {
				gs.star_power = 0
			}
		}
	}

	star_positions := [3]Vector2{gs.star_red.position, gs.star_blue.position, gs.star_green.position}
	star_colors := [3]Enemy_Color{.Red, .Blue, .Green}
	star_radius: f32 = 8

	for star_idx in 0..<3 {
		star_pos := star_positions[star_idx]
		star_color := star_colors[star_idx]

		enemy_idx := 0
		for enemy_idx < gs.enemy_count {
			enemy := &gs.enemies[enemy_idx]
			if enemy.color != star_color {
				enemy_idx += 1
				continue
			}

			dist := distance(star_pos, enemy.position)
			if dist < star_radius+enemy.size*0.5 {
				enemy.health -= 25
				if enemy.health <= 0 {
					gs.session_currency += ENEMY_KILL_REWARD
					gs.total_currency += ENEMY_KILL_REWARD

					remove_enemy(gs, enemy_idx)

					gs.star_power += 50
					if gs.star_power > gs.max_star_power {
						gs.star_power = gs.max_star_power
					}
					gs.score += 100
					break
				}
				break
			}

			enemy_idx += 1
		}
	}
}

update_menu_input :: proc(gs: ^Game_State) -> bool {
	if rl.IsKeyPressed(.UP) || rl.IsKeyPressed(.W) {
		gs.menu_selection -= 1
		if gs.menu_selection < 0 {
			gs.menu_selection = 2
		}
	}
	if rl.IsKeyPressed(.DOWN) || rl.IsKeyPressed(.S) {
		gs.menu_selection += 1
		if gs.menu_selection > 2 {
			gs.menu_selection = 0
		}
	}

	if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE) {
		switch gs.menu_selection {
		case 0:
			persistent_currency := gs.total_currency
			gs^ = create_game_state()
			gs.total_currency = persistent_currency
			gs.current_screen = .Playing
		case 1:
			gs.current_screen = .Upgrades
		case 2:
			return true
		}
	}

	return false
}

update_upgrades_input :: proc(gs: ^Game_State) {
	if rl.IsKeyPressed(.LEFT) || rl.IsKeyPressed(.A) {
		gs.skill_tree_tab -= 1
		if gs.skill_tree_tab < 0 {
			gs.skill_tree_tab = 2
		}
	}
	if rl.IsKeyPressed(.RIGHT) || rl.IsKeyPressed(.D) {
		gs.skill_tree_tab += 1
		if gs.skill_tree_tab > 2 {
			gs.skill_tree_tab = 0
		}
	}

	if rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.BACKSPACE) {
		gs.current_screen = .Menu
	}
}

update_pause_input :: proc(gs: ^Game_State) {
	if rl.IsKeyPressed(.UP) || rl.IsKeyPressed(.W) {
		gs.pause_selection = 0
	}
	if rl.IsKeyPressed(.DOWN) || rl.IsKeyPressed(.S) {
		gs.pause_selection = 1
	}

	if rl.IsKeyPressed(.ESCAPE) {
		gs.current_screen = .Playing
	}

		if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE) {
			if gs.pause_selection == 0 {
				gs.current_screen = .Playing
			} else {
				save_total_currency(gs.total_currency)
				gs.current_screen = .Menu
				gs.menu_selection = 0
			}
		}
}

update_game :: proc(gs: ^Game_State) -> bool {
	switch gs.current_screen {
	case .Menu, .Game_Over:
		return update_menu_input(gs)
	case .Upgrades:
		update_upgrades_input(gs)
		return false
	case .Paused:
		update_pause_input(gs)
		return false
	case .Playing:
		if rl.IsKeyPressed(.ESCAPE) {
			gs.current_screen = .Paused
			gs.pause_selection = 0
			return false
		}
	}

	update_player(&gs.player)
	update_star(&gs.star_red, gs.player.position, Vector2{40, -20})
	update_star(&gs.star_blue, gs.player.position, Vector2{-40, -20})
	update_star(&gs.star_green, gs.player.position, Vector2{0, 44.72136})

	update_enemies(gs)
	check_collisions(gs)

	gs.spawn_timer -= 1.0 / 60.0
	if gs.spawn_timer <= 0 {
		spawn_enemy(gs)
		gs.spawn_timer = gs.enemy_spawn_rate
	}

	gs.star_power -= 0.5
	if gs.star_power < 0 {
		gs.star_power = 0
		save_total_currency(gs.total_currency)
		gs.current_screen = .Game_Over
	}

	gs.elapsed_time += 1.0 / 60.0
	gs.base_enemy_health = 20.0 + gs.elapsed_time*5.5

	gs.enemy_spawn_rate = 2.0 - f32(gs.score)/5000.0
	if gs.enemy_spawn_rate < 0.5 {
		gs.enemy_spawn_rate = 0.5
	}

	return false
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

	draw_upgrades :: proc(gs: ^Game_State) {
	center_x := rl.GetScreenWidth() / 2
	screen_width := rl.GetScreenWidth()

	rl.DrawText("UPGRADES", center_x-100, 30, 40, rl.GOLD)
	rl.DrawText(rl.TextFormat("£%d", gs.total_currency), screen_width-180, 30, 30, rl.GOLD)

	tab_width: i32 = 200
	tab_height: i32 = 40
	tab_y: i32 = 100
	tab_names := [3]cstring{"RED STAR", "BLUE STAR", "GREEN STAR"}
	tab_colors := [3]rl.Color{rl.RED, rl.SKYBLUE, rl.GREEN}

	for i in 0..<3 {
		tab_x := center_x - 300 + i32(i)*tab_width
		color := tab_colors[i]
		if gs.skill_tree_tab != i {
			color = rl.DARKGRAY
		}
		rl.DrawRectangle(tab_x, tab_y, tab_width-10, tab_height, color)
		rl.DrawText(tab_names[i], tab_x+40, tab_y+10, 20, rl.WHITE)
	}

	tree_y: i32 = tab_y + tab_height + 20
	tree_h: i32 = 400
	active_color := tab_colors[gs.skill_tree_tab]

	rl.DrawRectangleLines(center_x-290, tree_y, 580, tree_h, active_color)

	node_size: i32 = 60
	node_spacing: i32 = 100

	rl.DrawRectangleLines(center_x-node_size/2, tree_y+30, node_size, node_size, active_color)
	rl.DrawText("?", center_x-8, tree_y+50, 25, active_color)

	rl.DrawRectangleLines(center_x-node_spacing-node_size/2, tree_y+30+node_spacing, node_size, node_size, rl.GRAY)
	rl.DrawText("?", center_x-node_spacing-8, tree_y+50+node_spacing, 25, rl.GRAY)

	rl.DrawRectangleLines(center_x+node_spacing-node_size/2, tree_y+30+node_spacing, node_size, node_size, rl.GRAY)
	rl.DrawText("?", center_x+node_spacing-8, tree_y+50+node_spacing, 25, rl.GRAY)

	rl.DrawRectangleLines(center_x-node_spacing*2-node_size/2, tree_y+30+node_spacing*2, node_size, node_size, rl.GRAY)
	rl.DrawText("?", center_x-node_spacing*2-8, tree_y+50+node_spacing*2, 25, rl.GRAY)

	rl.DrawRectangleLines(center_x-node_size/2, tree_y+30+node_spacing*2, node_size, node_size, rl.GRAY)
	rl.DrawText("?", center_x-8, tree_y+50+node_spacing*2, 25, rl.GRAY)

	rl.DrawRectangleLines(center_x+node_spacing*2-node_size/2, tree_y+30+node_spacing*2, node_size, node_size, rl.GRAY)
	rl.DrawText("?", center_x+node_spacing*2-8, tree_y+50+node_spacing*2, 25, rl.GRAY)

	rl.DrawLine(center_x, tree_y+30+node_size, center_x-node_spacing, tree_y+30+node_spacing, rl.GRAY)
	rl.DrawLine(center_x, tree_y+30+node_size, center_x+node_spacing, tree_y+30+node_spacing, rl.GRAY)

	rl.DrawText("A/D or Left/Right to switch trees, Escape to go back", center_x-230, rl.GetScreenHeight()-50, 16, rl.WHITE)
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

create_game_state :: proc() -> Game_State {
	return Game_State{
		player = Player{
			position = Vector2{640, 360},
			velocity = Vector2{0, 0},
			speed = 5.0,
			radius = 20,
		},
		star_red = Star{position = Vector2{680, 340}, radius = 8, speed = 0.2},
		star_blue = Star{position = Vector2{600, 340}, radius = 8, speed = 0.2},
		star_green = Star{position = Vector2{640, 400}, radius = 8, speed = 0.2},

		enemy_count = 0,

		star_power = 1800,
		max_star_power = 1800,
		enemy_spawn_rate = 2.0,
		spawn_timer = 2.0,
		base_enemy_health = 20.0,

		current_screen = .Menu,
		menu_selection = 0,
		pause_selection = 0,
		skill_tree_tab = 0,

		score = 0,
		session_currency = 0,
		total_currency = 0,
		elapsed_time = 0,
	}
}

main :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Bestagon")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)
	rl.SetExitKey(.KEY_NULL)

	game_state := create_game_state()
	game_state.total_currency = load_total_currency()

	for !rl.WindowShouldClose() {
		if update_game(&game_state) {
			break
		}
		draw_game(&game_state)
	}

	save_total_currency(game_state.total_currency)
}
