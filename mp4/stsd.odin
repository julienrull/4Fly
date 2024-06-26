package mp4

import "core:fmt"
import "core:mem"
import "core:slice"


SampleEntry :: struct {
	box:                  Box,
	reserved:             [6]byte,
	data_reference_index: u16be,
}

VisualSampleEntry :: struct {
	using sampleEntry: SampleEntry,
	pre_defined:       u16be, // = 0
	reserved2:         u16be, // = 0
	pre_defined2:      [3]u32be, // = 0
	width:             u16be,
	height:            u16be,
	horizresolution:   u32be, // = 0x00480000 72 dpi
	vertresolution:    u32be, // = 0x00480000; // 72 dpi
	reserved3:         u32be, // = 0;
	frame_count:       u16be, // = 1;
	compressorname:    [32]byte, // string[32]
	depth:             u16be, // = 0x0018;
	pre_defined3:      i16be, // = -1;
}

AudioSampleEntry :: struct {
	using sampleEntry: SampleEntry,
	reserved2:         [2]u32be, //= 0
	channelcount:      u16be, // = 2;
	samplesize:        u16be, // = 16;
	pre_defined:       u16be, // = 0;
	reserved3:         u16be, // = 0 ;
	samplerate:        u32be, // = {timescale of media}<<16;
}

HintSampleEntry :: struct {
	using sampleEntry: SampleEntry,
	data:              []byte,
}

// SampleDescriptionBox
Stsd :: struct {
	// stbl -> stsd
	fullbox:             FullBox,
	entry_count:         u32be,
	hintSampleEntries:   [dynamic]HintSampleEntry,
	visualSampleEntries: [dynamic]VisualSampleEntry,
	audioSampleEntries:  [dynamic]AudioSampleEntry,
	extensions: []byte
}


deserialize_stsd :: proc(data: []byte, handler_type: u32be) -> (stsd: Stsd, acc: u64) {
	fullbox, fullbox_size := deserialize_fullbox(data[acc:])
	stsd.fullbox = fullbox
	acc += fullbox_size
	size: u64
	if stsd.fullbox.box.size == 1 {
		size = u64(stsd.fullbox.box.largesize)
	}else if stsd.fullbox.box.size == 0 {
		size = u64(len(data))
	}else {
		size = u64(stsd.fullbox.box.size)
	}
	stsd.entry_count = (^u32be)(&data[acc])^
	acc += size_of(u32be)
	stsd.hintSampleEntries = make([dynamic]HintSampleEntry, 0, stsd.entry_count)
	stsd.visualSampleEntries = make([dynamic]VisualSampleEntry, 0, stsd.entry_count)
	stsd.audioSampleEntries = make([dynamic]AudioSampleEntry, 0, stsd.entry_count)
	handler_type_c := handler_type
	handler_type_s := to_string(&handler_type_c)
	//fmt.println(handler_type_s)
	for i := 0; i < int(stsd.entry_count); i += 1 {
		switch handler_type_s {
		// case "hint":
		//     append(&(stsd.hintSampleEntries), (^HintSampleEntry)(&data[acc])^)
		//     acc += size_of(HintSampleEntry)
		case "vide":
			box, box_size := deserialize_box(data[acc:])
			acc += box_size
			vide_size := size_of(VisualSampleEntry) - size_of(Box)
			vide := VisualSampleEntry{}
			vide.box = box
			vide_b := mem.ptr_to_bytes(&vide, size_of(VisualSampleEntry))
			new_vide_b := slice.concatenate(
				[][]byte{vide_b[:size_of(Box)], data[acc:acc + u64(vide_size)]},
			)
			new_vide := (^VisualSampleEntry)(&new_vide_b[0])^
			append(&(stsd.visualSampleEntries), new_vide)
			acc += u64(vide_size)
			// acc += size - box_size
		case "soun":
			box, box_size := deserialize_box(data[acc:])
			acc += box_size
			soun := AudioSampleEntry{}
			soun.box = box
			soun_size := size_of(AudioSampleEntry) - size_of(Box)
			soun_b := mem.ptr_to_bytes(&soun, size_of(AudioSampleEntry))
			new_soun_b := slice.concatenate(
				[][]byte{soun_b[:size_of(Box)], data[acc:acc + u64(soun_size)]},
			)
			new_soun := (^AudioSampleEntry)(&new_soun_b[0])^
			append(&(stsd.audioSampleEntries), new_soun)
			acc += u64(soun_size)
			// acc += size - box_size
		}
	}
	remain := size  - acc
	if remain > 0 {
		stsd.extensions = data[acc:acc + remain]
		acc += remain
	}
	return stsd, acc
}

serialize_stsd :: proc(stsd: Stsd, handler_type: u32be) -> (data: []byte) {
	fullbox_b := serialize_fullbox(stsd.fullbox)
	entry_count := stsd.entry_count
	entry_count_b := (^[4]byte)(&entry_count)^
	data = slice.concatenate([][]byte{fullbox_b[:], entry_count_b[:]})
	// if len(stsd.hintSampleEntries) > 0 {}
	if len(stsd.visualSampleEntries) > 0 {
		for i := 0; i < len(stsd.visualSampleEntries); i += 1 {
			box_b := serialize_box(stsd.visualSampleEntries[i].box)
			data = slice.concatenate([][]byte{data[:], box_b[:]})
			vide := stsd.visualSampleEntries[i]
			vide_b := (^[112]byte)(&vide)^
			data = slice.concatenate([][]byte{data[:], vide_b[size_of(Box):]})
		}
	}
	if len(stsd.audioSampleEntries) > 0 {
		for i := 0; i < len(stsd.audioSampleEntries); i += 1 {
			box_b := serialize_box(stsd.audioSampleEntries[i].box)
			data = slice.concatenate([][]byte{data[:], box_b[:]})
			soun := stsd.audioSampleEntries[i]
			soun_b := (^[64]byte)(&soun)^
			data = slice.concatenate([][]byte{data[:], soun_b[size_of(Box):]})
		}
	}
	if len(stsd.extensions) > 0 {
		data = slice.concatenate([][]byte{data[:], stsd.extensions[:]})
	}
	return data
}
