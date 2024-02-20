package main

import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:testing"
import "mp4"

TYPES := []string{"fmp4"}
ENTITIES := []string{"all", "m3u8", "init"}
CMDS := []string{"dump"}

cmd_args := make(map[string][]string)

get_cmd_args :: proc(
	args: []string,
) -> (
	cmd: string,
	path: string,
	time: f64,
	type: string,
	entity: string,
) {
	path = ""
	time = 3.0
	type = "fmp4"
	entity = "all"
	cmd_count := 0
	cmd = ""
	for arg in args {
		if arg[:1] != "-" && cmd_count == 0 {
			//if slice.contains(CMDS, arg) {
			//	path = arg
			//}
			path = arg
			cmd = arg
			cmd_count += 1
		} else if cmd == "dump" && len(arg) > 1 {
			path = arg
		} else if len(arg) > 1 && arg[:1] == "-" {
			col := strings.index(arg, ":")
			if col != -1 && len(arg) > col + 1 {
				param := arg[1:col]
				if param == "time" {
					prop := arg[col + 1:]
					t, ok := strconv.parse_f64(prop)
					if ok && t > 0 {
						time = t
					} else {
						// ERROR
						panic("ERROR: bad time value.")
					}
				} else if param == "type" {
					prop := arg[col + 1:]
					if slice.contains(TYPES, prop) {
						type = prop
					} else {
						// ERROR
						panic("ERROR: bad type value.")
					}
				} else if param == "entity" {
					prop := arg[col + 1:]
					s, ok := strconv.parse_int(prop)
					if slice.contains(ENTITIES, prop) || ok {
						entity = prop
					} else {
						// ERROR
						panic("ERROR: bad entity value.")
					}
				}
			} else {
				// ERROR
				panic("ERROR: flag value missing, should be -<flag>:<val>")
			}
		} else {
			// ERROR
			panic("ERROR: too many argument provided. Should be video path only.")
		}
	}
	return cmd, path, time, type, entity
}

main :: proc() {
	context.logger = log.create_console_logger()
	// # PROGRAM ARGS
	args := os.args[1:]
	cmd, path, time, type, entity := get_cmd_args(args)
	handle, err := mp4.fopen(path)
	defer os.close(handle)
	// ###
	if cmd == "dump" {
		dump_error := mp4.dump(handle)
		if dump_error != nil {
		    mp4.handle_dump_error(dump_error)
		}
	} else {
		if entity == "all" {
		} else if entity == "m3u8" {
			mp4.create_manifest(handle, time)
		} else if entity == "init" {
			mp4.create_init(handle)
		} else {
			err_frag := mp4.write_fragment(handle, u32be(strconv.atoi(entity)), time)
			if err_frag != nil {
				mp4.handle_file_error(err_frag)
			}
		}
	}
	//fmt.println("END")
}
