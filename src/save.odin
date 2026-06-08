package main

Save_Data :: struct {
	total_currency:     i32,
	purchased_upgrades: [UPGRADE_TAB_COUNT][MAX_UPGRADE_NODES]bool,
}

build_save_data :: proc(gs: ^Game_State) -> Save_Data {
	save := Save_Data {
		total_currency = gs.total_currency,
	}
	for tab_idx in 0 ..< UPGRADE_TAB_COUNT {
		count := gs.upgrade_node_counts[tab_idx]
		for node_idx in 0 ..< count {
			save.purchased_upgrades[tab_idx][node_idx] =
				gs.upgrade_nodes[tab_idx][node_idx].purchased
		}
	}
	return save
}

apply_save_data :: proc(gs: ^Game_State, save: Save_Data) {
	gs.total_currency = save.total_currency
	for tab_idx in 0 ..< UPGRADE_TAB_COUNT {
		count := gs.upgrade_node_counts[tab_idx]
		for node_idx in 0 ..< count {
			if node_idx == 0 {
				gs.upgrade_nodes[tab_idx][node_idx].purchased = true
				continue
			}
			gs.upgrade_nodes[tab_idx][node_idx].purchased =
				save.purchased_upgrades[tab_idx][node_idx]
		}
	}
}
