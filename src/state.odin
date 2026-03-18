package main

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
