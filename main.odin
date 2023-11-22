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
	size := os.file_size_from_path(args[0])
	f, ferr := os.open(args[0])
	if ferr != 0 {
		return
	}
	defer os.close(f)
	buffer, err := mem.alloc_bytes((int)(size))
	defer delete(buffer)
	os.read(f, buffer)
	//mp4.dump(buffer, u64(len(buffer)))


	mp4_file, mp4_file_size := mp4.deserialize_mp4(buffer, u64(len(buffer)))
	//data, err_masrshal := json.marshal(mp4_file)
	//fmt.println(string(data))
	
	ser_mp4_file := mp4.serialize_mp4(mp4_file)
	deser_mp4_file, deser_mp4_file_size := mp4.deserialize_mp4(ser_mp4_file, u64(len(ser_mp4_file)))
	fmt.println(deser_mp4_file)
}