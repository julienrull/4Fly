package mp4


import "core:bytes"
import "core:os"
import "core:slice"
import "core:strings"

Box :: struct {
	size:      u32be,
	type:      u32be,
	largesize: u64be, // if size == 1
	usertype:  [16]byte, // if type == uuid
}


BoxV2 :: struct {
	type:          string, // u32be
	usertype:      string, // if type == uuid -> u128be
	version:       u8,
	flags:         [3]byte,
	total_size:    u64be,
	header_size:   u64be,
	body_size:     u64be,
	position:      u64,
	is_large_size: bool,
	is_fullbox:    bool,
	is_container:  bool,
}

// TODO Is box exist error
read_box :: proc(handle: os.Handle) -> (box: BoxV2, err: FileError) {
	buffer := [8]u8{}
	total_read := fread(handle, buffer[:]) or_return
	box.total_size = u64be((^u32be)(&buffer[0])^)
	box.type = strings.clone_from_bytes(buffer[4:])
	if box.total_size == 1 {
		total_read += fread(handle, buffer[:]) or_return
		box.total_size = transmute(u64be)buffer
		box.is_large_size = true
	}
	if box.type == "uuid" {
		buffer_usertype := [16]u8{}
		total_read += fread(handle, buffer_usertype[:]) or_return
		box.usertype = strings.clone_from_bytes(buffer_usertype[:])
	}
	box.header_size = u64be(total_read)
	remain := box.total_size - box.header_size
	if remain != 0 {
		if remain >= 8 {
			readed := fread(handle, buffer[:]) or_return
			type_s := strings.clone_from_bytes(buffer[4:])
			if slice.contains(BOXES, type_s) {
				box.is_container = true
			}
			os.seek(handle, -i64(readed), os.SEEK_CUR)
		}
		if remain >= 4 && !box.is_container {
			if box.type != "ftyp" {
				total_read += fread(handle, buffer[:4]) or_return
				box.version = buffer[0]
				box.flags[0] = buffer[1]
				box.flags[1] = buffer[2]
				box.flags[2] = buffer[3]
				box.header_size += 4
				box.is_fullbox = true
			}
		}
	}
	box.body_size = box.total_size - box.header_size
	os.seek(handle, -i64(total_read), os.SEEK_CUR)
	return box, err
}

write_box :: proc(handle: os.Handle, box: BoxV2) -> FileError {
	data := bytes.Buffer{}
	bytes.buffer_init(&data, []u8{})
	box_to_bytes(box, &data)
	// TODO: handle io error for buffer_to_bytes
	total_write := fwrite(handle, bytes.buffer_to_bytes(&data)) or_return
	bytes.buffer_destroy(&data)
	return nil
}

box_to_bytes :: proc(box: BoxV2, buffer: ^bytes.Buffer) {
	size: u32be = 1
	type := box.type
	type_b := transmute([]u8)type
	type_n := (^u32be)(&type_b[0])^
	if box.is_large_size {
		bytes.buffer_write_ptr(buffer, &size, 4)
		bytes.buffer_write_ptr(buffer, &type_n, 4)
		largesize := box.total_size
		bytes.buffer_write_ptr(buffer, &largesize, 8)
	} else {
		size = u32be(box.total_size)
		bytes.buffer_write_ptr(buffer, &size, 4)
		bytes.buffer_write_ptr(buffer, &type_n, 4)
	}
	if box.usertype != "" {
		usertype := box.usertype
		bytes.buffer_write_ptr(buffer, &usertype, 16)
	}
	if box.is_fullbox {
		version := box.version
		flags := box.flags
		bytes.buffer_write_ptr(buffer, &version, 1)
		bytes.buffer_write_ptr(buffer, &flags, 3)
	}
}

serialize_box :: proc(box: Box) -> (data: []byte) {
	size := box.size
	size_b := (^[4]byte)(&size)^
	type := box.type
	type_s := to_string(&type)
	type_b := (^[4]byte)(&type)^
	data = slice.concatenate([][]byte{size_b[:], type_b[:]})
	if size == 1 {
		largesize := box.largesize
		largesize_b := (^[8]byte)(&largesize)^
		data = slice.concatenate([][]byte{data, largesize_b[:]})
	}
	if type_s == "uuid" {
		usertype := box.usertype
		usertype_b := (^[16]byte)(&usertype)^
		data = slice.concatenate([][]byte{data, usertype_b[:]})
	}
	return data
}

deserialize_box :: proc(data: []byte) -> (Box, u64) {
	acc: u64 = 0
	size := (^u32be)(&data[acc])^
	acc = acc + size_of(u32be)
	type := (^u32be)(&data[acc])^
	type_s := to_string(&type)
	acc = acc + size_of(u32be)
	largesize: u64be = 0
	usertype: [16]byte
	if size == 1 {
		largesize = (^u64be)(&data[acc])^
		acc = acc + size_of(u64be)
	} else if size == 0 {
		// TODO: box extends to end of file
	}
	if type_s == "uuid" {
		usertype = (^[16]byte)(&data[acc])^
		acc = acc + size_of([16]byte)
	}
	return Box{size, type, largesize, usertype}, acc
}
