package mp4

import "core:mem"
import "core:slice"
import "core:os"
import "core:fmt"
import "core:bytes"

// TimeToSampleBox
Stts :: struct {
	// stbl -> stts
	fullbox:     FullBox,
	entry_count: u32be,
	entries:     []TimeToSampleBoxEntrie,
}

TimeToSampleBoxEntrie :: struct {
	sample_count: u32be,
	sample_delta: u32be,
}

SttsV2 :: struct {
	// stbl -> stts
	box:			BoxV2,
	entry_count:	u32be,
	entries:		[]TimeToSampleBoxEntrie,
}

read_stts :: proc(handle: os.Handle, id: int = 1) -> (atom: SttsV2, err: FileError) {
    box := select_box(handle, "stts", id) or_return
    atom.box = box
    fseek(handle, i64(box.header_size), os.SEEK_CUR) or_return
    buffer := [4]u8{}
    fread(handle, buffer[:]) or_return
    atom.entry_count = transmute(u32be)buffer
	entries_b := make([]u8, atom.entry_count * 8)
    fread(handle, entries_b[:]) or_return
    atom.entries = (transmute([]TimeToSampleBoxEntrie)entries_b)[:atom.entry_count]
    return atom, nil
}

write_stts :: proc(handle: os.Handle, atom: SttsV2) -> FileError {
    data := bytes.Buffer{}
	atom_cpy := atom
    bytes.buffer_init(&data, []u8{})
	stts_to_bytes(atom, &data)
    total_write := fwrite(handle, bytes.buffer_to_bytes(&data)) or_return
    bytes.buffer_destroy(&data)
	return nil
}

stts_to_bytes :: proc(atom: SttsV2, buffer: ^bytes.Buffer){
	atom_cpy := atom
    box_to_bytes(atom_cpy.box, buffer)
    bytes.buffer_write_ptr(buffer, &atom_cpy.entry_count, 4)
	if atom_cpy.entry_count > 0 {
		bytes.buffer_write_ptr(buffer, &atom_cpy.entries,
		size_of(TimeToSampleBoxEntrie) * int(atom_cpy.entry_count))
	}
}

deserialize_stts :: proc(data: []byte) -> (stts: Stts, acc: u64) {
	// Stts main values
	fullbox, fullbox_size := deserialize_fullbox(data[acc:])
	stts.fullbox = fullbox
	acc += fullbox_size
	stts.entry_count = (^u32be)(&data[acc])^
	acc += size_of(u32be)
	// Stts entries values
	stts.entries = make([]TimeToSampleBoxEntrie, stts.entry_count)
	for i := 0; i < int(stts.entry_count); i += 1 {
		stts.entries[i] = (^TimeToSampleBoxEntrie)(&data[acc])^
		acc += size_of(TimeToSampleBoxEntrie)
	}
	return stts, acc
}

serialize_stts :: proc(stts: Stts) -> (data: []byte) {
	fullbox_b := serialize_fullbox(stts.fullbox)
	entry_count := stts.entry_count
	entry_count_b := (^[4]byte)(&entry_count)^
	data = slice.concatenate([][]byte{fullbox_b[:], entry_count_b[:]})
	if entry_count > 0 {
		for i := 0; i < int(stts.entry_count); i += 1 {
			entry := stts.entries[i]
			entry_b := (^[8]byte)(&entry)^
			data = slice.concatenate([][]byte{data[:], entry_b[:]})
		}
	}
	return data
}
