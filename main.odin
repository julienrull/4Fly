package main

import "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strings"
import "mp4"

main :: proc() {
	args := os.args[1:]
	size_video := os.file_size_from_path(args[0])
	size_seg := os.file_size_from_path(args[1])
	f_vid, f_vid_err := os.open(args[0])
	if f_vid_err != 0 {
		return
	}
	defer os.close(f_vid)
	f_seg, f_seg_err := os.open(args[1])
	if f_seg_err != 0 {
		return
	}
	defer os.close(f_seg)
	
	vid, vide_mem_err := mem.alloc_bytes((int)(size_video))
	seg, seg_mem_err := mem.alloc_bytes((int)(size_seg))
	defer delete(vid)
	defer delete(seg)
	os.read(f_vid, vid)
	os.read(f_seg, seg)
	// mp4_file, mp4_file_size := mp4.deserialize_mp4(seg, u64(size_seg))
	// fmt.printf("%v", json.marshal(mp4_file))
	mp4.recreate_seg_1(vid, seg)

	//mp4.dump(buffer, u64(len(buffer)))


	// mp4_file, mp4_file_size := mp4.deserialize_mp4(buffer, u64(len(buffer)))
	// ser_mp4_file := mp4.serialize_mp4(mp4_file)
	// deser_mp4_file, deser_mp4_file_size := mp4.deserialize_mp4(ser_mp4_file, u64(len(ser_mp4_file)))
	// fmt.println(deser_mp4_file)
}