package main

import "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strings"
import "mp4"

main :: proc() {
be:u16be = 3
be_b := (^[2]byte)(&be)^
bit := be & 0x0001

b: byte = 1

fmt.println(bit)
fmt.println(be_b)
fmt.println((^u16)(&b)^)

	// args := os.args[1:]
	// size := os.file_size_from_path(args[0])
	// f, ferr := os.open(args[0])
	// if ferr != 0 {
	// 	return
	// }
	// defer os.close(f)
	// buffer, err := mem.alloc_bytes((int)(size))
	// defer delete(buffer)
	// os.read(f, buffer)
	// mp4.dump(buffer, u64(len(buffer)))

	// frag, fraf_size := mp4.deserialize_fragment(buffer)
	// data, err_masrshal := json.marshal(frag)
	// fmt.println(string(data))
}


// test := 0b10000101_00000000
// mask := 0b00000000_00000001
// test_shift := test >> 8
// bit := test_shift & mask
// mask = 0b00000000_11111111
// rest := (test_shift >> 1) & mask
// fmt.println(bit)
// fmt.println(rest)
