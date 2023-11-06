package mp4

import "core:slice"
import "core:mem"

// SampleToChunkBox
Stsc :: struct {
    fullbox: FullBox,
    entry_count: u32be,
    entries: []SampleToChunkBoxEntries
}

SampleToChunkBoxEntries :: struct {
     first_chunk: u32be,
     samples_per_chunk: u32be,
     sample_description_index: u32be,
}

deserialize_stsc :: proc(data: []byte) -> (stsc: Stsc, acc: u64) {
    fullbox, fullbox_size :=  deserialize_fullbox(data[acc:])
    stsc.fullbox = fullbox
    acc += fullbox_size
    stsc.entry_count = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    if stsc.entry_count > 0 {
        entries := make([]SampleToChunkBoxEntries, stsc.entry_count)
        for i:=0; i<int(stsc.entry_count); i+=1 {
            entries[i] = (^SampleToChunkBoxEntries)(&data[acc])^
            acc += size_of(SampleToChunkBoxEntries)
        }
    }
    return stsc, acc
}

serialize_stsc :: proc(stsc: Stsc) -> (data: []byte){
    fullbox_b := serialize_fullbox(stsc.fullbox)
    entry_count := stsc.entry_count
    entry_count_b := (^[4]byte)(&entry_count)^
    data = slice.concatenate([][]byte{fullbox_b[:], entry_count_b[:]})
    if entry_count > 0 {
        entries := stsc.entries[:]
        entries_b := mem.ptr_to_bytes(&entries, size_of(SampleToChunkBoxEntries) * int(entry_count))
        data = slice.concatenate([][]byte{data[:], entries_b[:]})
    }
    return data
}