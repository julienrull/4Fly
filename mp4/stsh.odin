package mp4

import "core:slice"
import "core:mem"


// ShadowSyncSampleBox
Stsh :: struct {
    fullbox: FullBox,
    entry_count: u32be,
    entries: []ShadowSyncSampleBox
}

ShadowSyncSampleBox :: struct {
    shadowed_sample_number: u32be,
    sync_sample_number: u32be
}

deserialize_stsh :: proc(data: []byte) -> (stsh: Stsh, acc: u64) {
    fullbox, fullbox_size :=  deserialize_fullbox(data[acc:])
    acc += fullbox_size
    stsh.entry_count = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    stsh.entries = make([]ShadowSyncSampleBox, stsh.entry_count)
    for i:=0; i<int(stsh.entry_count); i+=1 {
        stsh.entries[i] = (^ShadowSyncSampleBox)(&data[acc])^
        acc += size_of(ShadowSyncSampleBox)
    }
    return stsh, acc
}

serialize_stsh :: proc(stsh: Stsh) -> (data: []byte) {
    fullbox_b := serialize_fullbox(stsh.fullbox)
    entry_count := stsh.entry_count
    entry_count_b := (^[4]byte)(&entry_count)^
    data = slice.concatenate([][]byte{fullbox_b[:], entry_count_b[:]})
    if entry_count > 0 {
        entries := stsh.entries[:]
        entries_b := mem.ptr_to_bytes(&entries, size_of(ShadowSyncSampleBox) * int(entry_count))
        data = slice.concatenate([][]byte{data[:], entries_b[:]})
    }
    return data
}