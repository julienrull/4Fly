package mp4

import "core:fmt"
import "core:mem"
import "core:slice"


// ABSTRACTION

SampleGroupDescriptionEntry :: struct {}

VisualSampleGroupEntry :: struct {
	using sge: SampleGroupDescriptionEntry,
}

AudioSampleGroupEntry :: struct {
	using sge: SampleGroupDescriptionEntry,
}

HintSampleGroupEntry :: struct {
	using sge: SampleGroupDescriptionEntry,
}

// IMPLEMENTATION

VisualRollRecoveryEntry :: struct {
	//using rre:     VisualSampleGroupEntry,
	roll_distance: i16be,
}


AudioRollRecoveryEntry :: struct {
	//using rre:     AudioSampleGroupEntry,
	roll_distance: i16be,
}

Sgpd :: struct {
	fullbox:                   FullBox,
	grouping_type:             u32be,
	default_length:            u32be,
	entry_count:               u32be,
	visualRollRecoveryEntries: [dynamic]VisualRollRecoveryEntry,
	audioRollRecoveryEntries:  [dynamic]AudioRollRecoveryEntry,
}

deserialize_sgpd :: proc(data: []byte, handler_type: u32be) -> (sgpd: Sgpd, acc: u64) {
	fullbox, fullbox_size := deserialize_fullbox(data[acc:])
	sgpd.fullbox = fullbox
	acc += fullbox_size
	sgpd.grouping_type = (^u32be)(&data[acc])^
	acc += size_of(u32be)
	sgpd.default_length = (^u32be)(&data[acc])^
	acc += size_of(u32be)
	sgpd.entry_count = (^u32be)(&data[acc])^
	acc += size_of(u32be)
	sgpd.visualRollRecoveryEntries = make([dynamic]VisualRollRecoveryEntry, 0, sgpd.entry_count)
	sgpd.audioRollRecoveryEntries = make([dynamic]AudioRollRecoveryEntry, 0, sgpd.entry_count)
	handler_type_c := handler_type
	handler_type_s := to_string(&handler_type_c)
	for i := 0; i < int(sgpd.entry_count); i += 1 {
		switch handler_type_s {
		case "vide":
			entry := (^VisualRollRecoveryEntry)(&data[acc])^
			append(&(sgpd.visualRollRecoveryEntries), entry)
			acc += u64(size_of(VisualRollRecoveryEntry))
		case "soun":
			entry := (^AudioRollRecoveryEntry)(&data[acc])^
			append(&(sgpd.audioRollRecoveryEntries), entry)
			acc += u64(size_of(AudioRollRecoveryEntry))
		}
	}

	return sgpd, acc
}


serialize_sgpd :: proc(sgpd: Sgpd, handler_type: u32be) -> (data: []byte) {
	fullbox_b := serialize_fullbox(sgpd.fullbox)
	grouping_type := sgpd.grouping_type
	grouping_type_b := (^[4]byte)(&grouping_type)^
	data = slice.concatenate([][]byte{fullbox_b[:], grouping_type_b[:]})
	default_length := sgpd.default_length
	default_length_b := (^[4]byte)(&default_length)^
	data = slice.concatenate([][]byte{data[:], default_length_b[:]})
	entry_count := sgpd.entry_count
	entry_count_b := (^[4]byte)(&entry_count)^
	data = slice.concatenate([][]byte{data[:], entry_count_b[:]})
	// if len(stsd.hintSampleEntries) > 0 {}
	if len(sgpd.visualRollRecoveryEntries) > 0 {
		for i := 0; i < len(sgpd.visualRollRecoveryEntries); i += 1 {
			entry := sgpd.visualRollRecoveryEntries[i]
			entry_b := (^[2]byte)(&entry)^
			data = slice.concatenate([][]byte{data[:], entry_b[:]})
		}
	}
	if len(sgpd.audioRollRecoveryEntries) > 0 {
		for i := 0; i < len(sgpd.audioRollRecoveryEntries); i += 1 {
			entry := sgpd.audioRollRecoveryEntries[i]
			entry_b := (^[2]byte)(&entry)^
			data = slice.concatenate([][]byte{data[:], entry_b[:]})
		}
	}
	return data
}
