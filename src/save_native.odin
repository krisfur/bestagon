#+build !js
package main

import "core:encoding/json"
import os "core:os"

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

save_progress :: proc(gs: ^Game_State) {
	save := build_save_data(gs)
	json_data, marshal_err := json.marshal(
		save,
		json.Marshal_Options{pretty = true},
		context.temp_allocator,
	)
	if marshal_err != nil {
		return
	}

	_ = os.write_entire_file_from_bytes(save_file_path(), json_data)
}
