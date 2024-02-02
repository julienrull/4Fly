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
			if slice.contains(CMDS, arg) {
				path = arg
			}
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
	// ###
	if cmd == "dump" {
		handle, err := mp4.fopen(path)
		defer os.close(handle)
		//write_err := mp4.write_fragment(handle)
		atom, read_err := mp4.read_mdhd(handle)
		log.debug(atom)
		//log.debugf("%8b\n", u32be(257) >> 1)
		//dump_error := mp4.dump(handle)
		//if dump_error != nil {
		//    mp4.handle_dump_error(dump_error)
		//}
	} else {
		dir, file := filepath.split(path)
		size_video := os.file_size_from_path(path)
		f_vid, f_vid_err := os.open(path)
		if f_vid_err != 0 {
			return
		}
		defer os.close(f_vid)
		vid, vide_mem_err := mem.alloc_bytes((int)(size_video))
		defer delete(vid)
		os.read(f_vid, vid)
		mp4_box, mp4_size := mp4.deserialize_mp4(vid, u64(size_video))
		segment_count := int(
			(f64(mp4_box.moov.mvhd.duration) / f64(mp4_box.moov.mvhd.timescale)) / time,
		)
		last_segment_duration :=
			(f64(mp4_box.moov.mvhd.duration) / f64(mp4_box.moov.mvhd.timescale)) -
			time * f64(segment_count)
		if entity == "all" {
			for i in 0 ..= segment_count {
				//for i in 0..=20 {
				// FRAGMENT
				segment_number := i
				segment := mp4.Segment{}
				if segment_number != segment_count {
					segment = mp4.new_segment(&mp4_box, segment_number, time)
				} else {
					segment = mp4.new_segment(&mp4_box, segment_number, last_segment_duration)
				}
				// * STYP
				seg_box := mp4.Mp4{}
				seg_box.styp = mp4.create_styp(segment)
				// * MOOF
				seg_box.moof = mp4.create_moof(segment)
				seg_box.mdat = mp4.create_mdat(segment, vid)
				// * SIDX
				sidxs := mp4.create_sidxs(segment, seg_box.moof.box.size + seg_box.mdat.box.size)
				clear(&seg_box.sidxs)
				for sidx in sidxs {
					append(&seg_box.sidxs, sidx)
				}
				new_seg := mp4.serialize_mp4(seg_box)
				handle, err := os.open(fmt.tprintf("%sseg-%d.m4s", dir, i), os.O_CREATE)
				os.write(handle, new_seg)
				os.close(handle)
			}
			mp4.create_manifest(segment_count, time, last_segment_duration, dir)
			init := mp4.create_init(mp4_box)
			init_b := mp4.serialize_mp4(init)
			init_handle, init_err := os.open(fmt.tprintf("%sinit.mp4", dir), os.O_CREATE)
			os.write(init_handle, init_b)
			os.close(init_handle)
		} else if entity == "m3u8" {
			mp4.create_manifest(segment_count, time, last_segment_duration, dir)
		} else if entity == "init" {
			init := mp4.create_init(mp4_box)
			init_b := mp4.serialize_mp4(init)
			init_handle, init_err := os.open(fmt.tprintf("%sinit.mp4", dir), os.O_CREATE)
			os.write(init_handle, init_b)
			os.close(init_handle)
		} else {
			// FRAGMENT
			segment_number := strconv.atoi(entity)
			segment := mp4.Segment{}
			if segment_number != segment_count {
				segment = mp4.new_segment(&mp4_box, segment_number, time)
			} else {
				segment = mp4.new_segment(&mp4_box, segment_number, last_segment_duration)
			}
			// * STYP
			seg_box := mp4.Mp4{}
			seg_box.styp = mp4.create_styp(segment)
			// * MOOF
			seg_box.moof = mp4.create_moof(segment)
			seg_box.mdat = mp4.create_mdat(segment, vid)
			// * SIDX
			sidxs := mp4.create_sidxs(segment, seg_box.moof.box.size + seg_box.mdat.box.size)
			clear(&seg_box.sidxs)
			for sidx in sidxs {
				append(&seg_box.sidxs, sidx)
			}
			new_seg := mp4.serialize_mp4(seg_box)
			handle, err := os.open(
				fmt.tprintf("%sseg-%d.m4s", dir, strconv.atoi(entity)),
				os.O_CREATE,
			)
			os.write(handle, new_seg)
			os.close(handle)
		}
	}
	//fmt.println("END")
}
