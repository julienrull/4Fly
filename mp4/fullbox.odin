package mp4

import "core:slice"

FullBox :: struct {
	box:     Box,
	version: u8,
	flags:   [3]byte,
}

deserialize_fullbox :: proc(data: []byte) -> (FullBox, u64) {
	acc: u64 = 0
	box, box_size := deserialize_box(data)
	acc = acc + box_size
	version := (^u8)(&data[acc])^
	acc = acc + size_of(u8)
	flags := (^[3]byte)(&data[acc])^
	acc = acc + size_of([3]byte)
	return FullBox{box, version, flags}, acc
}

serialize_fullbox :: proc(fullbox: FullBox) -> (data: []byte) {
	box_b := serialize_box(fullbox.box)
	version := fullbox.version
	version_b := (^[1]byte)(&version)^
	flags_b := fullbox.flags
	data = slice.concatenate([][]byte{box_b[:], version_b[:]})
	data = slice.concatenate([][]byte{data[:], flags_b[:]})
	return data
}
