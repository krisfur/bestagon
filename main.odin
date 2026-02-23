package main

import "core:math"
import "core:encoding/json"
import os "core:os/os2"
import rl "vendor:raylib"

WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720
MAX_ENEMIES :: 1024
UPGRADE_TAB_COUNT :: 3
MAX_UPGRADE_NODES :: 16
ENEMY_KILL_REWARD :: i32(20)
SAVE_FILE_NAME :: ".bestagon_save.json"

Enemy_Color :: enum i32 {
	Red,
	Blue,
	Green,
}

Upgrade_Tab :: enum i32 {
	Red,
	Green,
	Blue,
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

Upgrade_Node :: struct {
	position: Vector2,
	parent_index: int,
	name: cstring,
	description: cstring,
	price: i32,
	purchased: bool,
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
	skill_tree_tab: Upgrade_Tab,
	reset_confirm_open: bool,
	reset_confirm_yes_selected: bool,
	selected_upgrade_node: [UPGRADE_TAB_COUNT]int,
	upgrade_scroll_y: f32,

	upgrade_nodes: [UPGRADE_TAB_COUNT][MAX_UPGRADE_NODES]Upgrade_Node,
	upgrade_node_counts: [UPGRADE_TAB_COUNT]int,

	score: i32,
	session_currency: i32,
	total_currency: i32,
	elapsed_time: f32,
}

Save_Data :: struct {
	total_currency: i32,
	purchased_upgrades: [UPGRADE_TAB_COUNT][MAX_UPGRADE_NODES]bool,
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

load_save_data :: proc() -> Save_Data {
	data, err := os.read_entire_file_from_path(save_file_path(), context.temp_allocator)
	if err != nil {
		return Save_Data{}
	}

	save := Save_Data{}
	unmarshal_err := json.unmarshal(data, &save)
	if unmarshal_err != nil {
		return Save_Data{}
	}

	if save.total_currency < 0 {
		save.total_currency = 0
	}

	return save
}

build_save_data :: proc(gs: ^Game_State) -> Save_Data {
	save := Save_Data{total_currency = gs.total_currency}
	for tab_idx in 0..<UPGRADE_TAB_COUNT {
		count := gs.upgrade_node_counts[tab_idx]
		for node_idx in 0..<count {
			save.purchased_upgrades[tab_idx][node_idx] = gs.upgrade_nodes[tab_idx][node_idx].purchased
		}
	}
	return save
}

apply_save_data :: proc(gs: ^Game_State, save: Save_Data) {
	gs.total_currency = save.total_currency
	for tab_idx in 0..<UPGRADE_TAB_COUNT {
		count := gs.upgrade_node_counts[tab_idx]
		for node_idx in 0..<count {
			if node_idx == 0 {
				gs.upgrade_nodes[tab_idx][node_idx].purchased = true
				continue
			}
			gs.upgrade_nodes[tab_idx][node_idx].purchased = save.purchased_upgrades[tab_idx][node_idx]
		}
	}
}

reset_all_progress :: proc(gs: ^Game_State) {
	gs.total_currency = 0
	gs.session_currency = 0
	for tab_idx in 0..<UPGRADE_TAB_COUNT {
		count := gs.upgrade_node_counts[tab_idx]
		for node_idx in 0..<count {
			gs.upgrade_nodes[tab_idx][node_idx].purchased = node_idx == 0
		}
	}
	save_progress(gs)
}

save_progress :: proc(gs: ^Game_State) {
	save := build_save_data(gs)
	json_data, marshal_err := json.marshal(save, json.Marshal_Options{pretty = true}, context.temp_allocator)
	if marshal_err != nil {
		return
	}

	_ = os.write_entire_file_from_bytes(save_file_path(), json_data)
}

upgrade_tab_index :: proc(tab: Upgrade_Tab) -> int {
	return int(tab)
}

upgrade_tab_color :: proc(tab: Upgrade_Tab) -> rl.Color {
	switch tab {
	case .Red:
		return rl.RED
	case .Green:
		return rl.GREEN
	case .Blue:
		return rl.SKYBLUE
	}
	return rl.GRAY
}

set_upgrade_node :: proc(gs: ^Game_State, tab: Upgrade_Tab, index: int, x, y: f32, parent_index: int, name, description: cstring, price: i32, purchased := false) {
	if index < 0 || index >= MAX_UPGRADE_NODES {
		return
	}
	tab_idx := upgrade_tab_index(tab)
	gs.upgrade_nodes[tab_idx][index] = Upgrade_Node{
		position = Vector2{x, y},
		parent_index = parent_index,
		name = name,
		description = description,
		price = price,
		purchased = purchased,
	}
}

init_upgrade_tree_for_tab :: proc(gs: ^Game_State, tab: Upgrade_Tab) {
	tab_idx := upgrade_tab_index(tab)
	gs.upgrade_node_counts[tab_idx] = 8
	gs.selected_upgrade_node[tab_idx] = 0

	set_upgrade_node(gs, tab, 0, 0, 50, -1, "Core", "Unlock this color path", 0, true)
	set_upgrade_node(gs, tab, 1, -130, 170, 0, "Upgrade 1", "Upgrade 1 desc", 60)
	set_upgrade_node(gs, tab, 2, 130, 170, 0, "Upgrade 2", "Upgrade 2 desc", 60)
	set_upgrade_node(gs, tab, 3, -200, 310, 1, "Upgrade 3", "Upgrade 3 desc", 110)
	set_upgrade_node(gs, tab, 4, 0, 310, 1, "Upgrade 4", "Upgrade 4 desc", 120)
	set_upgrade_node(gs, tab, 5, 200, 310, 2, "Upgrade 5", "Upgrade 5 desc", 110)
	set_upgrade_node(gs, tab, 6, 0, 470, 4, "Upgrade 6", "Upgrade 6 desc", 220)
	set_upgrade_node(gs, tab, 7, 0, 640, 6, "Upgrade 7", "Upgrade 7 desc", 360)
}

init_upgrade_trees :: proc(gs: ^Game_State) {
	init_upgrade_tree_for_tab(gs, .Red)
	init_upgrade_tree_for_tab(gs, .Green)
	init_upgrade_tree_for_tab(gs, .Blue)
	gs.upgrade_scroll_y = 0
}

upgrade_node_is_unlocked :: proc(gs: ^Game_State, tab: Upgrade_Tab, node_index: int) -> bool {
	tab_idx := upgrade_tab_index(tab)
	node := gs.upgrade_nodes[tab_idx][node_index]
	if node.parent_index < 0 {
		return true
	}
	return gs.upgrade_nodes[tab_idx][node.parent_index].purchased
}

upgrade_content_max_scroll :: proc(gs: ^Game_State, tab: Upgrade_Tab, viewport_height: f32) -> f32 {
	tab_idx := upgrade_tab_index(tab)
	max_y: f32 = 0
	for i in 0..<gs.upgrade_node_counts[tab_idx] {
		node_y := gs.upgrade_nodes[tab_idx][i].position.y
		if node_y > max_y {
			max_y = node_y
		}
	}
	max_scroll := max_y + 100 - viewport_height
	if max_scroll < 0 {
		max_scroll = 0
	}
	return max_scroll
}

clamp_upgrade_scroll :: proc(gs: ^Game_State) {
	max_scroll := upgrade_content_max_scroll(gs, gs.skill_tree_tab, 400)
	if gs.upgrade_scroll_y < 0 {
		gs.upgrade_scroll_y = 0
	}
	if gs.upgrade_scroll_y > max_scroll {
		gs.upgrade_scroll_y = max_scroll
	}
}

ensure_selected_upgrade_visible :: proc(gs: ^Game_State) {
	tab_idx := upgrade_tab_index(gs.skill_tree_tab)
	selected := gs.selected_upgrade_node[tab_idx]
	if selected < 0 || selected >= gs.upgrade_node_counts[tab_idx] {
		return
	}
	node_y := gs.upgrade_nodes[tab_idx][selected].position.y
	top_margin: f32 = 40
	bottom_margin: f32 = 360
	if node_y-gs.upgrade_scroll_y < top_margin {
		gs.upgrade_scroll_y = node_y - top_margin
	}
	if node_y-gs.upgrade_scroll_y > bottom_margin {
		gs.upgrade_scroll_y = node_y - bottom_margin
	}
	clamp_upgrade_scroll(gs)
}

select_neighbor_upgrade_node :: proc(gs: ^Game_State, horizontal, vertical: int) {
	tab_idx := upgrade_tab_index(gs.skill_tree_tab)
	count := gs.upgrade_node_counts[tab_idx]
	if count <= 0 {
		return
	}

	current := gs.selected_upgrade_node[tab_idx]
	if current < 0 || current >= count {
		current = 0
		gs.selected_upgrade_node[tab_idx] = 0
	}

	origin := gs.upgrade_nodes[tab_idx][current].position
	best_index := current
	best_score: f32 = 1e9

	for i in 0..<count {
		if i == current {
			continue
		}

		candidate := gs.upgrade_nodes[tab_idx][i].position
		dx := candidate.x - origin.x
		dy := candidate.y - origin.y

		if horizontal > 0 && dx <= 0 {
			continue
		}
		if horizontal < 0 && dx >= 0 {
			continue
		}
		if vertical > 0 && dy <= 0 {
			continue
		}
		if vertical < 0 && dy >= 0 {
			continue
		}

		primary := math.abs(dx)
		secondary := math.abs(dy)
		if vertical != 0 {
			primary = math.abs(dy)
			secondary = math.abs(dx)
		}

		score := primary + secondary*1.7
		if score < best_score {
			best_score = score
			best_index = i
		}
	}

	if best_index != current {
		gs.selected_upgrade_node[tab_idx] = best_index
		ensure_selected_upgrade_visible(gs)
	}
}

try_purchase_selected_upgrade :: proc(gs: ^Game_State) {
	tab_idx := upgrade_tab_index(gs.skill_tree_tab)
	selected := gs.selected_upgrade_node[tab_idx]
	count := gs.upgrade_node_counts[tab_idx]
	if selected < 0 || selected >= count {
		return
	}

	node := &gs.upgrade_nodes[tab_idx][selected]
	if node.purchased {
		return
	}
	if !upgrade_node_is_unlocked(gs, gs.skill_tree_tab, selected) {
		return
	}
	if gs.total_currency < node.price {
		return
	}

	gs.total_currency -= node.price
	node.purchased = true
	save_progress(gs)
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

reset_run_state :: proc(gs: ^Game_State) {
	gs.player = Player{
		position = Vector2{640, 360},
		velocity = Vector2{0, 0},
		speed = 5.0,
		radius = 20,
	}
	gs.star_red = Star{position = Vector2{680, 340}, radius = 8, speed = 0.2}
	gs.star_blue = Star{position = Vector2{600, 340}, radius = 8, speed = 0.2}
	gs.star_green = Star{position = Vector2{640, 400}, radius = 8, speed = 0.2}

	gs.enemy_count = 0
	gs.star_power = 1800
	gs.max_star_power = 1800
	gs.enemy_spawn_rate = 2.0
	gs.spawn_timer = 2.0
	gs.base_enemy_health = 20.0

	gs.current_screen = .Playing
	gs.pause_selection = 0
	gs.score = 0
	gs.session_currency = 0
	gs.elapsed_time = 0
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
			reset_run_state(gs)
		case 1:
			gs.current_screen = .Upgrades
			gs.reset_confirm_open = false
			ensure_selected_upgrade_visible(gs)
		case 2:
			return true
		}
	}

	return false
}

update_upgrades_input :: proc(gs: ^Game_State) {
	if gs.reset_confirm_open {
		if rl.IsKeyPressed(.A) || rl.IsKeyPressed(.LEFT) || rl.IsKeyPressed(.D) || rl.IsKeyPressed(.RIGHT) {
			gs.reset_confirm_yes_selected = !gs.reset_confirm_yes_selected
		}

		if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE) {
			if gs.reset_confirm_yes_selected {
				reset_all_progress(gs)
			}
			gs.reset_confirm_open = false
			return
		}

		if rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.BACKSPACE) || rl.IsKeyPressed(.R) {
			gs.reset_confirm_open = false
			return
		}

		return
	}

	if rl.IsKeyPressed(.Q) {
		if gs.skill_tree_tab == .Red {
			gs.skill_tree_tab = .Blue
		} else {
			gs.skill_tree_tab = Upgrade_Tab(i32(gs.skill_tree_tab) - 1)
		}
		ensure_selected_upgrade_visible(gs)
	}
	if rl.IsKeyPressed(.E) {
		if gs.skill_tree_tab == .Blue {
			gs.skill_tree_tab = .Red
		} else {
			gs.skill_tree_tab = Upgrade_Tab(i32(gs.skill_tree_tab) + 1)
		}
		ensure_selected_upgrade_visible(gs)
	}

	if rl.IsKeyPressed(.A) || rl.IsKeyPressed(.LEFT) {
		select_neighbor_upgrade_node(gs, -1, 0)
	}
	if rl.IsKeyPressed(.D) || rl.IsKeyPressed(.RIGHT) {
		select_neighbor_upgrade_node(gs, 1, 0)
	}
	if rl.IsKeyPressed(.W) || rl.IsKeyPressed(.UP) {
		select_neighbor_upgrade_node(gs, 0, -1)
	}
	if rl.IsKeyPressed(.S) || rl.IsKeyPressed(.DOWN) {
		select_neighbor_upgrade_node(gs, 0, 1)
	}

	if rl.IsKeyPressed(.SPACE) || rl.IsKeyPressed(.ENTER) {
		try_purchase_selected_upgrade(gs)
	}

	if rl.IsKeyPressed(.R) {
		gs.reset_confirm_open = true
		gs.reset_confirm_yes_selected = false
		return
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
				save_progress(gs)
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
		save_progress(gs)
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

	tree_x := center_x - 290
	tree_w: i32 = 580
	tab_width: i32 = tree_w / 3
	tab_height: i32 = 40
	tab_y: i32 = 100
	tab_names := [3]cstring{"RED STAR", "GREEN STAR", "BLUE STAR"}
	tab_order := [3]Upgrade_Tab{.Red, .Green, .Blue}

	for i in 0..<3 {
		tab := tab_order[i]
		tab_x := tree_x + i32(i)*tab_width
		current_tab_w := tab_width
		if i == 2 {
			current_tab_w = tree_w - tab_width*2
		}
		color := upgrade_tab_color(tab)
		if gs.skill_tree_tab != tab {
			color = rl.DARKGRAY
		}
		rl.DrawRectangle(tab_x, tab_y, current_tab_w, tab_height, color)
		tab_text := tab_names[i]
		tab_text_w := rl.MeasureText(tab_text, 20)
		rl.DrawText(tab_text, tab_x+(current_tab_w-tab_text_w)/2, tab_y+10, 20, rl.WHITE)
	}

	tree_y: i32 = tab_y + tab_height + 20
	tree_h: i32 = 400
	active_color := upgrade_tab_color(gs.skill_tree_tab)

	rl.DrawRectangleLines(tree_x, tree_y, tree_w, tree_h, active_color)

	tab_idx := upgrade_tab_index(gs.skill_tree_tab)
	count := gs.upgrade_node_counts[tab_idx]
	node_size: i32 = 52

	clamp_upgrade_scroll(gs)

	rl.BeginScissorMode(tree_x+1, tree_y+1, tree_w-2, tree_h-2)

	for i in 0..<count {
		node := gs.upgrade_nodes[tab_idx][i]
		if node.parent_index < 0 {
			continue
		}

		parent := gs.upgrade_nodes[tab_idx][node.parent_index]
		x1 := f32(center_x) + parent.position.x
		y1 := f32(tree_y) + parent.position.y - gs.upgrade_scroll_y
		x2 := f32(center_x) + node.position.x
		y2 := f32(tree_y) + node.position.y - gs.upgrade_scroll_y

		line_color := rl.DARKGRAY
		if parent.purchased && upgrade_node_is_unlocked(gs, gs.skill_tree_tab, i) {
			line_color = active_color
		}
		rl.DrawLine(i32(x1), i32(y1), i32(x2), i32(y2), line_color)
	}

	selected := gs.selected_upgrade_node[tab_idx]
	for i in 0..<count {
		node := gs.upgrade_nodes[tab_idx][i]
		x := f32(center_x) + node.position.x
		y := f32(tree_y) + node.position.y - gs.upgrade_scroll_y

		rect_x := i32(x) - node_size/2
		rect_y := i32(y) - node_size/2

		locked := !upgrade_node_is_unlocked(gs, gs.skill_tree_tab, i)
		fill := rl.Color([4]u8{45, 45, 55, 255})
		if locked {
			fill = rl.Color([4]u8{30, 30, 35, 255})
		} else if node.purchased {
			fill = active_color
		}

		rl.DrawRectangle(rect_x, rect_y, node_size, node_size, fill)

		outline := rl.BLACK
		if i == selected {
			outline = rl.YELLOW
		}
		rl.DrawRectangleLines(rect_x, rect_y, node_size, node_size, outline)
	}

	rl.EndScissorMode()

	if selected >= 0 && selected < count {
		node := gs.upgrade_nodes[tab_idx][selected]
		node_screen_x := i32(f32(center_x) + node.position.x)
		node_screen_y := i32(f32(tree_y) + node.position.y - gs.upgrade_scroll_y)

		info_w: i32 = 290
		info_h: i32 = 118
		info_x := node_screen_x + 45
		if info_x+info_w > tree_x+tree_w {
			info_x = node_screen_x - info_w - 45
		}
		info_y := node_screen_y - info_h/2
		if info_y < tree_y+5 {
			info_y = tree_y + 5
		}
		if info_y+info_h > tree_y+tree_h-5 {
			info_y = tree_y + tree_h - info_h - 5
		}

		rl.DrawRectangle(info_x, info_y, info_w, info_h, rl.Color([4]u8{18, 18, 26, 240}))
		rl.DrawRectangleLines(info_x, info_y, info_w, info_h, active_color)

		rl.DrawText(node.name, info_x+12, info_y+10, 22, rl.WHITE)
		rl.DrawText(node.description, info_x+12, info_y+42, 16, rl.LIGHTGRAY)

		status_color := rl.GOLD
		status_text := rl.TextFormat("Price: £%d", node.price)
		if node.purchased {
			status_text = "Purchased"
			status_color = rl.GREEN
		} else if !upgrade_node_is_unlocked(gs, gs.skill_tree_tab, selected) {
			status_text = "Locked: buy previous node"
			status_color = rl.GRAY
		} else if gs.total_currency < node.price {
			status_color = rl.RED
		}

		rl.DrawText(status_text, info_x+12, info_y+82, 18, status_color)
	}

	upgrade_hint: cstring = "Q/E tab  WASD/Arrows move  Space/Enter buy  Esc back"
	hint_w := rl.MeasureText(upgrade_hint, 16)
	rl.DrawText(upgrade_hint, center_x-hint_w/2, rl.GetScreenHeight()-50, 16, rl.WHITE)

	reset_hint: cstring = "R TO RESET"
	reset_x: i32 = 20
	reset_y := rl.GetScreenHeight() - 50
	rl.DrawText(reset_hint, reset_x-1, reset_y, 20, rl.BLACK)
	rl.DrawText(reset_hint, reset_x+1, reset_y, 20, rl.BLACK)
	rl.DrawText(reset_hint, reset_x, reset_y-1, 20, rl.BLACK)
	rl.DrawText(reset_hint, reset_x, reset_y+1, 20, rl.BLACK)
	rl.DrawText(reset_hint, reset_x, reset_y, 20, rl.RED)

	if gs.reset_confirm_open {
		rl.DrawRectangle(0, 0, rl.GetScreenWidth(), rl.GetScreenHeight(), rl.Fade(rl.BLACK, 0.65))

		popup_w: i32 = 560
		popup_h: i32 = 220
		popup_x := center_x - popup_w/2
		popup_y := rl.GetScreenHeight()/2 - popup_h/2

		rl.DrawRectangle(popup_x, popup_y, popup_w, popup_h, rl.Color([4]u8{20, 20, 30, 250}))
		rl.DrawRectangleLines(popup_x, popup_y, popup_w, popup_h, rl.RED)

		title: cstring = "Reset all upgrades and money?"
		title_w := rl.MeasureText(title, 30)
		rl.DrawText(title, center_x-title_w/2, popup_y+30, 30, rl.WHITE)

		rl.DrawText("This action cannot be undone.", center_x-145, popup_y+78, 20, rl.LIGHTGRAY)

		yes_color := rl.GRAY
		no_color := rl.GRAY
		if gs.reset_confirm_yes_selected {
			yes_color = rl.GREEN
		} else {
			no_color = rl.GREEN
		}

		rl.DrawRectangleLines(center_x-150, popup_y+130, 120, 46, yes_color)
		rl.DrawText("YES", center_x-111, popup_y+143, 24, yes_color)

		rl.DrawRectangleLines(center_x+30, popup_y+130, 120, 46, no_color)
		rl.DrawText("NO", center_x+74, popup_y+143, 24, no_color)

		rl.DrawText("A/D or Left/Right to choose, Space/Enter to confirm", center_x-220, popup_y+188, 16, rl.WHITE)
	}
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
	gs := Game_State{
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
		skill_tree_tab = .Red,
		reset_confirm_open = false,
		reset_confirm_yes_selected = false,
		selected_upgrade_node = [UPGRADE_TAB_COUNT]int{0, 0, 0},
		upgrade_scroll_y = 0,

		score = 0,
		session_currency = 0,
		total_currency = 0,
		elapsed_time = 0,
	}

	init_upgrade_trees(&gs)
	return gs
}

main :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Bestagon")
	defer rl.CloseWindow()

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
