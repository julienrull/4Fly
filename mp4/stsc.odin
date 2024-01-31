package mp4

import "core:slice"
import "core:mem"
import "core:fmt"
import "core:os"

// SampleToChunkBox
Stsc :: struct {
    fullbox:        FullBox,
    entry_count:    u32be,
    entries:        []SampleToChunkBoxEntries
}

SampleToChunkBoxEntries :: struct {
     first_chunk:               u32be,
     samples_per_chunk:         u32be,
     sample_description_index:  u32be,
}


StscV2 :: struct {
    box:            BoxV2,
    entry_count:    u32be,
    entries:        []SampleToChunkBoxEntries
}

read_stsc :: proc(handle: os.Handle) -> (atom: StscV2, err: FileError) {
    box := select_box(handle, "stsc") or_return
    atom.box = box
    fseek(handle, i64(box.header_size), os.SEEK_CUR) or_return
    buffer := [4]u8{}
    fread(handle, buffer[:]) or_return
    atom.entry_count = transmute(u32be)buffer
	entries_b := make([]u8, atom.entry_count * 12)
    fread(handle, entries_b[:]) or_return
    atom.entries = (transmute([]SampleToChunkBoxEntries)entries_b)[:atom.entry_count]
    return atom, nil
}

deserialize_stsc :: proc(data: []byte) -> (stsc: Stsc, acc: u64) {
    fullbox, fullbox_size :=  deserialize_fullbox(data[acc:])
    stsc.fullbox = fullbox
    acc += fullbox_size
    stsc.entry_count = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    if stsc.entry_count > 0 {
        stsc.entries = make([]SampleToChunkBoxEntries, stsc.entry_count)
        for i:=0; i<int(stsc.entry_count); i+=1 {
            stsc.entries[i] = (^SampleToChunkBoxEntries)(&data[acc])^
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
    for i:=0;i<int(entry_count);i+=1{
        entry := stsc.entries[i]
        entry_b := (^[12]byte)(&entry)^
        data = slice.concatenate([][]byte{data[:], entry_b[:]})
    }
    // if entry_count > 0 {
    //     entries := stsc.entries[:]
    //     entries_b := mem.ptr_to_bytes(&entries, size_of(SampleToChunkBoxEntries) * int(entry_count))
    //     data = slice.concatenate([][]byte{data[:], entries_b[:]})
    // }
    return data
}
