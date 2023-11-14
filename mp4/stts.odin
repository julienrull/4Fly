package mp4

import "core:mem"
import "core:slice"

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
	entries := stts.entries
	if entry_count > 0 {
		entries_b := mem.ptr_to_bytes(&entries, size_of(TimeToSampleBoxEntrie) * int(entry_count))
		data = slice.concatenate([][]byte{data[:], entries_b[:]})
	}
	return data
}
