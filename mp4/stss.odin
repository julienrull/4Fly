package mp4

import "core:slice"
import "core:mem"

// SyncSampleBox
Stss :: struct {
    fullbox: FullBox,
    entry_count: u32be,
    samples_numbers: []u32be
}

deserialize_stss :: proc(data: []byte) -> (stss: Stss, acc: u64) {
    fullbox, fullbox_size :=  deserialize_fullbox(data[acc:])
    stss.fullbox = fullbox
    acc += fullbox_size
    stss.entry_count = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    stss.samples_numbers = make([]u32be, stss.entry_count)
    for i:=0; i<int(stss.entry_count); i+=1 {
        stss.samples_numbers[i] = (^u32be)(&data[acc])^
        acc += size_of(u32be)
    }
    return stss, acc
}

serialize_stss :: proc(stss: Stss) -> (data: []byte) {
    fullbox_b := serialize_fullbox(stss.fullbox)
    entry_count := stss.entry_count
    entry_count_b := (^[4]byte)(&entry_count)^
    data = slice.concatenate([][]byte{fullbox_b[:], entry_count_b[:]})
    if entry_count > 0 {
        for i := 0; i < int(stss.entry_count); i += 1 {
            entry := stss.samples_numbers[i]
            entry_b := (^[4]byte)(&entry)^
            data = slice.concatenate([][]byte{data[:], entry_b[:]})
        }
    }
    // if entry_count > 0 {
    //     samples_numbers := stss.samples_numbers[:]
    //     samples_numbers_b := mem.ptr_to_bytes(&samples_numbers, size_of(u32be) * int(entry_count))
    //     data = slice.concatenate([][]byte{data[:], samples_numbers_b[:]})
    // }
    return data
}