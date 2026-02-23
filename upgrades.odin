package main

import "core:math"
import rl "vendor:raylib"

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
