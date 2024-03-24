package mp4

import "core:mem"
import "core:os"
import "core:slice"
import "core:bytes"

// ChunkOffsetBox
Stco :: struct {
	fullbox:        FullBox,
	entry_count:    u32be,
	chunks_offsets: []u32be,
}

// ChunkLargeOffsetBox
Co64 :: struct {
	fullbox:        FullBox,
	entry_count:    u32be,
	chunks_offsets: []u64be,
}

StcoV2 :: struct {
	box:         BoxV2,
	entry_count: u32be,
	entries:     []u32be,
}

Co64V2 :: struct {
	box:         BoxV2,
	entry_count: u32be,
	entries:     []u64be,
}

read_stco :: proc(handle: os.Handle, id: int = 1) -> (atom: StcoV2, err: FileError) {
	box := select_box(handle, "stco", id) or_return
	atom.box = box
	fseek(handle, i64(box.header_size), os.SEEK_CUR) or_return
	buffer := [4]u8{}
	fread(handle, buffer[:]) or_return
	atom.entry_count = transmute(u32be)buffer
	entries_b := make([]u8, atom.entry_count * 4)
	fread(handle, entries_b[:]) or_return
	atom.entries = (transmute([]u32be)entries_b)[:atom.entry_count]
	return atom, nil
}

write_stco :: proc(handle: os.Handle, atom: StcoV2) -> FileError {
    data := bytes.Buffer{}
	atom_cpy := atom
    bytes.buffer_init(&data, []u8{})
    bytes.buffer_write_ptr(&data, &atom_cpy.entry_count, 4)
    bytes.buffer_write_ptr(&data, &atom_cpy.entries,
	size_of(u32be) * int(atom_cpy.entry_count))
    write_box(handle, atom_cpy.box) or_return
    total_write := fwrite(handle, bytes.buffer_to_bytes(&data)) or_return
    bytes.buffer_destroy(&data)
	return nil
}

read_co64 :: proc(handle: os.Handle, id: int = 1) -> (atom: Co64V2, err: FileError) {
	box := select_box(handle, "co64", id) or_return
	atom.box = box
	fseek(handle, i64(box.header_size), os.SEEK_CUR) or_return
	buffer := [4]u8{}
	fread(handle, buffer[:]) or_return
	atom.entry_count = transmute(u32be)buffer
	entries_b := make([]u8, atom.entry_count * 8)
	fread(handle, entries_b[:]) or_return
	atom.entries = (transmute([]u64be)entries_b)[:atom.entry_count]
	return atom, nil
}

write_co64 :: proc(handle: os.Handle, atom: Co64V2) -> FileError {
    data := bytes.Buffer{}
	atom_cpy := atom
    bytes.buffer_init(&data, []u8{})
    bytes.buffer_write_ptr(&data, &atom_cpy.entry_count, 4)
    bytes.buffer_write_ptr(&data, &atom_cpy.entries,
	size_of(u64be) * int(atom_cpy.entry_count))
    write_box(handle, atom_cpy.box) or_return
    total_write := fwrite(handle, bytes.buffer_to_bytes(&data)) or_return
    bytes.buffer_destroy(&data)
	return nil
}

deserialize_stco :: proc(data: []byte) -> (stco: Stco, acc: u64) {
	fullbox, fullbox_size := deserialize_fullbox(data[acc:])
	stco.fullbox = fullbox
	acc += fullbox_size
	stco.entry_count = (^u32be)(&data[acc])^
	acc += size_of(u32be)
	stco.chunks_offsets = make([]u32be, stco.entry_count)
	for i := 0; i < int(stco.entry_count); i += 1 {
		stco.chunks_offsets[i] = (^u32be)(&data[acc])^
		acc += size_of(u32be)
	}
	return stco, acc
}

deserialize_co64 :: proc(data: []byte) -> (co64: Co64, acc: u64) {
	fullbox, fullbox_size := deserialize_fullbox(data[acc:])
	co64.fullbox = fullbox
	acc += fullbox_size
	co64.entry_count = (^u32be)(&data[acc])^
	acc += size_of(u32be)
	co64.chunks_offsets = make([]u64be, co64.entry_count)
	for i := 0; i < int(co64.entry_count); i += 1 {
		co64.chunks_offsets[i] = (^u64be)(&data[acc])^
		acc += size_of(u64be)
	}
	return co64, acc
}

serialize_stco :: proc(stco: Stco) -> (data: []byte) {
	fullbox_b := serialize_fullbox(stco.fullbox)
	entry_count := stco.entry_count
	entry_count_b := (^[4]byte)(&entry_count)^
	data = slice.concatenate([][]byte{fullbox_b[:], entry_count_b[:]})
	if entry_count > 0 {
		for i := 0; i < int(stco.entry_count); i += 1 {
			entry := stco.chunks_offsets[i]
			entry_b := (^[4]byte)(&entry)^
			data = slice.concatenate([][]byte{data[:], entry_b[:]})
		}
	}

	// if entry_count > 0 {
	//     chunks_offsets := stco.chunks_offsets[:]
	//     chunks_offsets_b := mem.ptr_to_bytes(&chunks_offsets, size_of(u32be) * int(entry_count))
	//     data = slice.concatenate([][]byte{data[:], chunks_offsets_b[:]})
	// }
	return data
}

serialize_co64 :: proc(co64: Co64) -> (data: []byte) {
	fullbox_b := serialize_fullbox(co64.fullbox)
	entry_count := co64.entry_count
	entry_count_b := (^[4]byte)(&entry_count)^
	data = slice.concatenate([][]byte{fullbox_b[:], entry_count_b[:]})
	if entry_count > 0 {
		for i := 0; i < int(co64.entry_count); i += 1 {
			entry := co64.chunks_offsets[i]
			entry_b := (^[8]byte)(&entry)^
			data = slice.concatenate([][]byte{data[:], entry_b[:]})
		}
	}
	// if entry_count > 0 {
	//     chunks_offsets := co64.chunks_offsets[:]
	//     chunks_offsets_b := mem.ptr_to_bytes(&chunks_offsets, size_of(u64be) * int(entry_count))
	//     data = slice.concatenate([][]byte{data[:], chunks_offsets_b[:]})
	// }
	return data
}
