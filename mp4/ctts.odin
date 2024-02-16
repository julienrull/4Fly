package mp4

import "core:log"
import "core:mem"
import "core:slice"
import "core:os"

// CompositionOffsetBox
Ctts :: struct {
	// stbl -> ctts
	fullbox:     FullBox,
	entry_count: u32be,
	entries:     []CompositionOffsetBoxEntries,
}

CompositionOffsetBoxEntries :: struct {
	sample_count:  u32be,
	sample_offset: u32be,
}

CttsV2 :: struct {
	// stbl -> ctts
	box:		 BoxV2,
	entry_count: u32be,
	entries:     []CompositionOffsetBoxEntries,
}

read_ctts :: proc(handle: os.Handle, id: int = 1) -> (atom: CttsV2, err: FileError) {
    box := select_box(handle, "ctts", id) or_return
    atom.box = box
    fseek(handle, i64(box.header_size), os.SEEK_CUR) or_return
    buffer := [4]u8{}
    fread(handle, buffer[:]) or_return
    log.debug("???")
    atom.entry_count = transmute(u32be)buffer
	entries_b := make([]u8, atom.entry_count * 8)
    fread(handle, entries_b[:]) or_return
    atom.entries = (transmute([]CompositionOffsetBoxEntries)entries_b)[:atom.entry_count]
    return atom, nil
}

deserialize_ctts :: proc(data: []byte) -> (ctts: Ctts, acc: u64) {
	// Stts main values
	fullbox, fullbox_size := deserialize_fullbox(data[acc:])
	ctts.fullbox = fullbox
	acc += fullbox_size
	ctts.entry_count = (^u32be)(&data[acc])^
	acc += size_of(u32be)
	// Stts entries values
	ctts.entries = make([]CompositionOffsetBoxEntries, ctts.entry_count)
	for i := 0; i < int(ctts.entry_count); i += 1 {
		ctts.entries[i] = (^CompositionOffsetBoxEntries)(&data[acc])^
		acc += size_of(CompositionOffsetBoxEntries)
	}
	return ctts, acc
}

serialize_ctts :: proc(ctts: Ctts) -> (data: []byte) {
	fullbox_b := serialize_fullbox(ctts.fullbox)
	entry_count := ctts.entry_count
	entry_count_b := (^[4]byte)(&entry_count)^
	data = slice.concatenate([][]byte{fullbox_b[:], entry_count_b[:]})
	for i := 0; i < int(entry_count); i += 1 {
		entry := ctts.entries[i]
		entry_b := (^[8]byte)(&entry)^
		data = slice.concatenate([][]byte{data[:], entry_b[:]})
	}
	// if entry_count > 0 {
	//     entries_b := mem.ptr_to_bytes(&entries, int(entry_count))
	//     fmt.println(mem.byte_slice(&entries, int(entry_count)))
	//     data = slice.concatenate([][]byte{data[:], entries_b[:]})
	// }
	return data
}
