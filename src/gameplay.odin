package main

import "core:math"
import rl "vendor:raylib"

distance :: proc(a, b: Vector2) -> f32 {
	dx := a.x - b.x
	dy := a.y - b.y
	return math.sqrt(dx * dx + dy * dy)
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

	sw := f32(logical_width())
	sh := f32(logical_height())

	if player.position.x - player.radius < 0 {
		player.position.x = player.radius
	}
	if player.position.x + player.radius > sw {
		player.position.x = sw - player.radius
	}
	if player.position.y - player.radius < 0 {
		player.position.y = player.radius
	}
	if player.position.y + player.radius > sh {
		player.position.y = sh - player.radius
	}
}

update_star :: proc(star: ^Star, player_pos, offset: Vector2) {
	target_x := player_pos.x + offset.x
	target_y := player_pos.y + offset.y

	star.position.x += (target_x - star.position.x) * star.speed
	star.position.y += (target_y - star.position.y) * star.speed
}

enemy_reward :: proc(enemy: ^Enemy) -> i32 {
	mult: f32 = 1.0
	switch enemy.kind {
	case .Square:
		mult = 1.0
	case .Circle:
		mult = 1.5
	case .Triangle:
		mult = 2.0
	}
	if enemy.is_large {
		mult *= 2.0
	}
	return i32(f32(ENEMY_KILL_REWARD) * mult)
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

	sw := f32(logical_width())
	sh := f32(logical_height())

	new_enemy := Enemy{}
	new_enemy.color = Enemy_Color(rl.GetRandomValue(0, 2))
	new_enemy.kind = Enemy_Kind(rl.GetRandomValue(0, 2))
	new_enemy.is_large = rl.GetRandomValue(0, LARGE_SPAWN_CHANCE - 1) == 0

	base_size: f32 = 30
	new_enemy.size = new_enemy.is_large ? base_size * LARGE_SIZE_MULT : base_size
	new_enemy.max_health = new_enemy.is_large ? gs.base_enemy_health * LARGE_HEALTH_MULT : gs.base_enemy_health
	new_enemy.health = new_enemy.max_health

	if new_enemy.kind == .Triangle {
		new_enemy.timer = TRIANGLE_APPROACH_DUR
	}

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

move_toward_player :: proc(enemy: ^Enemy, player_pos: Vector2, speed: f32) {
	dx := player_pos.x - enemy.position.x
	dy := player_pos.y - enemy.position.y
	dist := distance(enemy.position, player_pos)
	if dist > 0 {
		enemy.position.x += (dx / dist) * speed
		enemy.position.y += (dy / dist) * speed
	}
}

// Triangles approach slowly, pause to charge, then dash toward the player.
update_triangle_enemy :: proc(enemy: ^Enemy, player_pos: Vector2, dt, speed_mult: f32) {
	enemy.timer -= dt
	switch enemy.phase {
	case 0: // approach
		move_toward_player(enemy, player_pos, TRIANGLE_APPROACH_SPEED * speed_mult)
		if enemy.timer <= 0 {
			enemy.phase = 1
			enemy.timer = TRIANGLE_CHARGE_DUR
		}
	case 1: // charge in place, lock dash direction when it ends
		if enemy.timer <= 0 {
			dx := player_pos.x - enemy.position.x
			dy := player_pos.y - enemy.position.y
			dist := distance(enemy.position, player_pos)
			enemy.velocity = dist > 0 ? Vector2{dx / dist, dy / dist} : Vector2{0, 0}
			enemy.phase = 2
			enemy.timer = TRIANGLE_DASH_DUR
		}
	case 2: // dash along the locked direction (full speed even for large, so the lunge still connects)
		enemy.position.x += enemy.velocity.x * TRIANGLE_DASH_SPEED
		enemy.position.y += enemy.velocity.y * TRIANGLE_DASH_SPEED
		if enemy.timer <= 0 {
			enemy.phase = 0
			enemy.timer = TRIANGLE_APPROACH_DUR
		}
	}
}

// Circles weave toward the player tracing a figure-8.
update_circle_enemy :: proc(enemy: ^Enemy, player_pos: Vector2, dt, speed_mult: f32) {
	enemy.weave += CIRCLE_WEAVE_FREQ * dt
	dx := player_pos.x - enemy.position.x
	dy := player_pos.y - enemy.position.y
	dist := distance(enemy.position, player_pos)
	if dist <= 0 {
		return
	}
	fwd := Vector2{dx / dist, dy / dist}
	perp := Vector2{-fwd.y, fwd.x}
	forward := (CIRCLE_FORWARD_SPEED + math.sin(enemy.weave * 2) * CIRCLE_FORWARD_AMP) * speed_mult
	lateral := math.sin(enemy.weave) * CIRCLE_LATERAL_AMP * speed_mult
	enemy.position.x += fwd.x * forward + perp.x * lateral
	enemy.position.y += fwd.y * forward + perp.y * lateral
}

update_enemies :: proc(gs: ^Game_State) {
	dt: f32 = 1.0 / 60.0
	i := 0
	for i < gs.enemy_count {
		enemy := &gs.enemies[i]
		speed_mult: f32 = enemy.is_large ? LARGE_SPEED_MULT : 1.0

		switch enemy.kind {
		case .Square:
			move_toward_player(enemy, gs.player.position, ENEMY_BASE_SPEED * speed_mult)
		case .Triangle:
			update_triangle_enemy(enemy, gs.player.position, dt, speed_mult)
		case .Circle:
			update_circle_enemy(enemy, gs.player.position, dt, speed_mult)
		}

		sw := f32(logical_width())
		sh := f32(logical_height())
		if enemy.position.x < -50 ||
		   enemy.position.x > sw + 50 ||
		   enemy.position.y < -50 ||
		   enemy.position.y > sh + 50 {
			remove_enemy(gs, i)
			continue
		}

		i += 1
	}
}

check_collisions :: proc(gs: ^Game_State) {
	for i in 0 ..< gs.enemy_count {
		enemy := &gs.enemies[i]
		dist := distance(gs.player.position, enemy.position)
		if dist < gs.player.radius + enemy.size * 0.5 {
			dx := gs.player.position.x - enemy.position.x
			dy := gs.player.position.y - enemy.position.y
			bounce_dist: f32 = 50
			bounce_len := math.sqrt(dx * dx + dy * dy)
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

	star_positions := [3]Vector2 {
		gs.star_red.position,
		gs.star_blue.position,
		gs.star_green.position,
	}
	star_colors := [3]Enemy_Color{.Red, .Blue, .Green}
	star_radius: f32 = 8

	for star_idx in 0 ..< 3 {
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
			if dist < star_radius + enemy.size * 0.5 {
				enemy.health -= 25
				if enemy.health <= 0 {
					reward := enemy_reward(enemy)
					gs.session_currency += reward
					gs.total_currency += reward

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
	gs.player = Player {
		position = Vector2{640, 360},
		velocity = Vector2{0, 0},
		speed    = 5.0,
		radius   = 20,
	}
	gs.star_red = Star {
		position = Vector2{680, 340},
		radius   = 8,
		speed    = 0.2,
	}
	gs.star_blue = Star {
		position = Vector2{600, 340},
		radius   = 8,
		speed    = 0.2,
	}
	gs.star_green = Star {
		position = Vector2{640, 400},
		radius   = 8,
		speed    = 0.2,
	}

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
	gs.base_enemy_health = 20.0 + gs.elapsed_time * 10

	gs.enemy_spawn_rate = 2.0 - f32(gs.score) / 5000.0
	if gs.enemy_spawn_rate < 0.5 {
		gs.enemy_spawn_rate = 0.5
	}

	return false
}
