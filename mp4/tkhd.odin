package mp4

import "core:os"
import "core:bytes"
import "core:slice"

// TrackHeaderBox
Tkhd :: struct {
	// trak -> tkhd
	fullbox:                   FullBox,
	creation_time:             u32be,
	creation_time_extends:     u64be,
	modification_time:         u32be,
	modification_time_extends: u64be,
	track_ID:                  u32be,
	reserved:                  u32be,
	duration:                  u32be,
	duration_extends:          u64be,
	reserved2:                 [2]u32be,
	layer:                     i16be,
	alternate_group:           i16be,
	volume:                    i16be,
	reserved3:                 u16be,
	matrixx:                   [9]i32be,
	width:                     u32be,
	height:                    u32be,
}


TkhdV2 :: struct {
	box:               BoxV2,
	creation_time:     u64be,
	modification_time: u64be,
	track_ID:          u32be,
	duration:          u64be,
	layer:             i16be,
	alternate_group:   i16be,
	volume:            i16be,
	matrixx:           [9]i32be,
	width:             u32be,
	height:            u32be,
}

read_tkhd :: proc(handle: os.Handle, id: int = 1) -> (atom: TkhdV2, err: FileError) {
	box := select_box(handle, "tkhd", id) or_return
	atom.box = box
	total_seek := fseek(handle, i64(box.header_size), os.SEEK_CUR) or_return
	buffer := [8]u8{}
	if box.version == 1 {
		fread(handle, buffer[:]) or_return
		atom.creation_time = transmute(u64be)buffer
		fread(handle, buffer[:]) or_return
		atom.modification_time = transmute(u64be)buffer
		fread(handle, buffer[:4]) or_return
		atom.track_ID = (transmute([]u32be)buffer[:4])[0]
		fseek(handle, 4, os.SEEK_CUR) or_return
		fread(handle, buffer[:]) or_return
		atom.duration = transmute(u64be)buffer
	} else {
		fread(handle, buffer[:4]) or_return
		atom.creation_time = u64be((transmute([]u32be)buffer[:4])[0])
		fread(handle, buffer[:4]) or_return
		atom.modification_time = transmute(u64be)buffer
		fread(handle, buffer[:4]) or_return
		atom.track_ID = (transmute([]u32be)buffer[:4])[0]
		fseek(handle, 4, os.SEEK_CUR) or_return
		fread(handle, buffer[:4]) or_return
		atom.duration = u64be((transmute([]u32be)buffer[:4])[0])
	}
	fseek(handle, 8, os.SEEK_CUR) or_return
	fread(handle, buffer[:2]) or_return
	atom.layer = (transmute([]i16be)buffer[:2])[0]
	fread(handle, buffer[:2]) or_return
	atom.alternate_group = (transmute([]i16be)buffer[:2])[0]
	fread(handle, buffer[:2]) or_return
	atom.volume = (transmute([]i16be)buffer[:2])[0]
	fseek(handle, 2, os.SEEK_CUR) or_return
	buffer2 := [36]u8{}
	fread(handle, buffer2[:]) or_return
	atom.matrixx = transmute([9]i32be)buffer2
	fread(handle, buffer[:4]) or_return
	atom.width = (transmute([]u32be)buffer[:4])[0]
	fread(handle, buffer[:4]) or_return
	atom.height = (transmute([]u32be)buffer[:4])[0]
	return atom, nil
}

write_tkhd :: proc(handle: os.Handle, atom: TkhdV2) -> FileError {
	data := bytes.Buffer{}
	atom_cpy := atom
	bytes.buffer_init(&data, []u8{})
	if atom_cpy.box.version == 1 {
		bytes.buffer_write_ptr(&data, &atom_cpy.creation_time, 8)
		bytes.buffer_write_ptr(&data, &atom_cpy.modification_time, 8)
		bytes.buffer_write_ptr(&data, &atom_cpy.track_ID, 4)
		bytes.buffer_write_ptr(&data, &[4]u8{0, 0, 0, 0}, 4)
		bytes.buffer_write_ptr(&data, &atom_cpy.duration, 8)
	} else {
		creation_time := u32be(atom_cpy.creation_time)
		bytes.buffer_write_ptr(&data, &creation_time, 4)
		modification_time := u32be(atom_cpy.modification_time)
		bytes.buffer_write_ptr(&data, &modification_time, 4)
		bytes.buffer_write_ptr(&data, &atom_cpy.track_ID, 4)
		bytes.buffer_write_ptr(&data, &[4]u8{0, 0, 0, 0}, 4)
		duration := u32be(atom_cpy.duration)
		bytes.buffer_write_ptr(&data, &duration, 4)
	}
	bytes.buffer_write_ptr(&data, &[8]u8{0, 0, 0, 0, 0, 0, 0, 0}, 8)
	bytes.buffer_write_ptr(&data, &atom_cpy.layer, 2)
	bytes.buffer_write_ptr(&data, &atom_cpy.alternate_group, 2)
	bytes.buffer_write_ptr(&data, &atom_cpy.volume, 2)
	bytes.buffer_write_ptr(&data, &[2]u8{0, 0}, 2)
	bytes.buffer_write_ptr(&data, &atom_cpy.matrixx, 36)
	bytes.buffer_write_ptr(&data, &atom_cpy.width, 4)
	bytes.buffer_write_ptr(&data, &atom_cpy.height, 4)
	write_box(handle, atom_cpy.box) or_return
	total_write := fwrite(handle, bytes.buffer_to_bytes(&data)) or_return
	bytes.buffer_destroy(&data)
	return nil
}

deserialize_tkhd :: proc(data: []byte) -> (tkhd: Tkhd, acc: u64) {
	fullbox, fullbox_size := deserialize_fullbox(data[acc:])
	tkhd.fullbox = fullbox
	acc += fullbox_size
	if fullbox.version == 1 {
		tkhd.creation_time_extends = (^u64be)(&data[acc])^
		acc += size_of(u64be)
		tkhd.modification_time_extends = (^u64be)(&data[acc])^
		acc += size_of(u64be)
		tkhd.track_ID = (^u32be)(&data[acc])^
		acc += size_of(u32be)
		tkhd.reserved = (^u32be)(&data[acc])^
		acc += size_of(u32be)
		tkhd.duration_extends = (^u64be)(&data[acc])^
		acc += size_of(u64be)
	} else {
		tkhd.creation_time = (^u32be)(&data[acc])^
		acc += size_of(u32be)
		tkhd.modification_time = (^u32be)(&data[acc])^
		acc += size_of(u32be)
		tkhd.track_ID = (^u32be)(&data[acc])^
		acc += size_of(u32be)
		tkhd.reserved = (^u32be)(&data[acc])^
		acc += size_of(u32be)
		tkhd.duration = (^u32be)(&data[acc])^
		acc += size_of(u32be)
	}

	tkhd.reserved2 = (^[2]u32be)(&data[acc])^
	acc += size_of([2]u32be)

	tkhd.layer = (^i16be)(&data[acc])^
	acc += size_of(i16be)

	tkhd.alternate_group = (^i16be)(&data[acc])^
	acc += size_of(i16be)

	tkhd.volume = (^i16be)(&data[acc])^
	acc += size_of(i16be)

	tkhd.reserved3 = (^u16be)(&data[acc])^
	acc += size_of(u16be)

	tkhd.matrixx = (^[9]i32be)(&data[acc])^
	acc += size_of([9]i32be)

	tkhd.width = (^u32be)(&data[acc])^
	acc += size_of(u32be)

	tkhd.height = (^u32be)(&data[acc])^
	acc += size_of(u32be)

	return tkhd, acc
}

serialize_tkhd :: proc(tkhd: Tkhd) -> (data: []byte) {
	fullbox_b := serialize_fullbox(tkhd.fullbox)
	if tkhd.fullbox.version == 1 {
		creation_time_extends := tkhd.creation_time_extends
		creation_time_extends_b := (^[8]byte)(&creation_time_extends)^
		data = slice.concatenate([][]byte{fullbox_b[:], creation_time_extends_b[:]})
		modification_time_extends := tkhd.modification_time_extends
		modification_time_extends_b := (^[8]byte)(&modification_time_extends)^
		data = slice.concatenate([][]byte{data[:], modification_time_extends_b[:]})
		track_ID := tkhd.track_ID
		track_ID_b := (^[4]byte)(&track_ID)^
		data = slice.concatenate([][]byte{data[:], track_ID_b[:]})
		reserved := tkhd.reserved
		reserved_b := (^[4]byte)(&reserved)^
		data = slice.concatenate([][]byte{data[:], track_ID_b[:]})
		duration_extends := tkhd.duration_extends
		duration_extends_b := (^[8]byte)(&duration_extends)^
		data = slice.concatenate([][]byte{data[:], duration_extends_b[:]})
	} else {
		creation_time := tkhd.creation_time
		creation_time_b := (^[4]byte)(&creation_time)^
		data = slice.concatenate([][]byte{fullbox_b[:], creation_time_b[:]})
		modification_time := tkhd.modification_time
		modification_time_b := (^[4]byte)(&modification_time)^
		data = slice.concatenate([][]byte{data[:], modification_time_b[:]})
		track_ID := tkhd.track_ID
		track_ID_b := (^[4]byte)(&track_ID)^
		data = slice.concatenate([][]byte{data[:], track_ID_b[:]})
		reserved := tkhd.reserved
		reserved_b := (^[4]byte)(&reserved)^
		data = slice.concatenate([][]byte{data[:], track_ID_b[:]})
		duration := tkhd.duration
		duration_b := (^[4]byte)(&duration)^
		data = slice.concatenate([][]byte{data[:], duration_b[:]})
	}

	reserved2 := tkhd.reserved2
	reserved2_b := (^[8]byte)(&reserved2)^
	data = slice.concatenate([][]byte{data[:], reserved2_b[:]})

	layer := tkhd.layer
	layer_b := (^[2]byte)(&layer)^
	data = slice.concatenate([][]byte{data[:], layer_b[:]})

	alternate_group := tkhd.alternate_group
	alternate_group_b := (^[2]byte)(&alternate_group)^
	data = slice.concatenate([][]byte{data[:], alternate_group_b[:]})

	volume := tkhd.volume
	volume_b := (^[2]byte)(&volume)^
	data = slice.concatenate([][]byte{data[:], volume_b[:]})

	reserved3 := tkhd.reserved3
	reserved3_b := (^[2]byte)(&reserved3)^
	data = slice.concatenate([][]byte{data[:], reserved3_b[:]})

	matrixx := tkhd.matrixx
	matrixx_b := (^[36]byte)(&matrixx)^
	data = slice.concatenate([][]byte{data[:], matrixx_b[:]})

	width := tkhd.width
	width_b := (^[4]byte)(&width)^
	data = slice.concatenate([][]byte{data[:], width_b[:]})

	height := tkhd.height
	height_b := (^[4]byte)(&height)^
	data = slice.concatenate([][]byte{data[:], height_b[:]})

	return data
}
