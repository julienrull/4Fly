package main

import json "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strings"
import "mp4"

main :: proc() {
// test := 0b10000101_00000000
// mask := 0b00000000_00000001
// test_shift := test >> 8
// bit := test_shift & mask
// mask = 0b00000000_11111111
// rest := (test_shift >> 1) & mask
// fmt.println(bit)
// fmt.println(rest)
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

	mp4.dump(buffer, u64(len(buffer)))
}
