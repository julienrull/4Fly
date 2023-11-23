package mp4

import "core:fmt"
import "core:mem"
import "core:slice"

SampleToGroupBoxEntry :: struct {
	sample_count:            u32be,
	group_description_index: u32be,
}

Sbgp :: struct {
	fullbox:                 FullBox,
	grouping_type:           u32be,
	entry_count:             u32be,
	sampleToGroupBoxEntries: []SampleToGroupBoxEntry,
}

deserialize_sbgp :: proc(data: []byte) -> (sbgp: Sbgp, acc: u64) {
    fullbox, fullbox_size := deserialize_fullbox(data[acc:])
    sbgp.fullbox = fullbox
    acc += fullbox_size
    sbgp.grouping_type = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    sbgp.entry_count = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    sbgp.sampleToGroupBoxEntries = make([]SampleToGroupBoxEntry, sbgp.entry_count)
    for i:=0;i<int(sbgp.entry_count);i+=1 {
        sbgp.sampleToGroupBoxEntries[i] = (^SampleToGroupBoxEntry)(&data[acc])^
        acc += size_of(SampleToGroupBoxEntry)
    }
	return sbgp, acc
}

serialize_sbgp :: proc(sbgp: Sbgp) -> (data: []byte) {
    fullbox_b := serialize_fullbox(sbgp.fullbox)
    grouping_type := sbgp.grouping_type
    grouping_type_b := (^[4]byte)(&grouping_type)^
    data = slice.concatenate([][]byte{fullbox_b[:], grouping_type_b[:]})    
    entry_count := sbgp.entry_count
    entry_count_b := (^[4]byte)(&entry_count)^
    data = slice.concatenate([][]byte{data[:], entry_count_b[:]})
    for i:=0;i<int(sbgp.entry_count);i+=1 {
        entry := sbgp.sampleToGroupBoxEntries[i]
        entry_b := (^[8]byte)(&entry)^
        data = slice.concatenate([][]byte{data[:], entry_b[:]})
    }
	return data
}
