package mp4

import "core:mem"
import "core:slice"
import "core:fmt"

// CompositionOffsetBox
Ctts :: struct{ // stbl -> ctts
    fullbox:        FullBox,
    entry_count:    u32be,
    entries :       []CompositionOffsetBoxEntries
}

CompositionOffsetBoxEntries :: struct {
    sample_count: u32be,
    sample_offset: u32be
}

deserialize_ctts :: proc(data: []byte) -> (ctts: Ctts, acc: u64) {
    // Stts main values
    fullbox, fullbox_size :=  deserialize_fullbox(data[acc:])
    ctts.fullbox = fullbox
    acc += fullbox_size
    ctts.entry_count = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    // Stts entries values
    ctts.entries = make([]CompositionOffsetBoxEntries, ctts.entry_count)
    for i:=0; i<int(ctts.entry_count); i+=1 {
        ctts.entries[i] = (^CompositionOffsetBoxEntries)(&data[acc])^
        acc += size_of(CompositionOffsetBoxEntries)
    }
    return ctts, acc
}

serialize_ctts :: proc(ctts: Ctts) -> (data: []byte){
    fullbox_b := serialize_fullbox(ctts.fullbox)
    entry_count := ctts.entry_count
    entry_count_b := (^[4]byte)(&entry_count)^
    data = slice.concatenate([][]byte{fullbox_b[:], entry_count_b[:]})
    entries := ctts.entries
    for i:=0;i<int(entry_count);i+=1{
        entry := entries[i]
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