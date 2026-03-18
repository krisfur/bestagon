package main

import "core:encoding/json"
import os "core:os"

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

save_progress :: proc(gs: ^Game_State) {
	save := build_save_data(gs)
	json_data, marshal_err := json.marshal(save, json.Marshal_Options{pretty = true}, context.temp_allocator)
	if marshal_err != nil {
		return
	}

	_ = os.write_entire_file_from_bytes(save_file_path(), json_data)
}
