package mp4

import "core:slice"
import "core:mem"
import "core:fmt"

// SampleSizeBox
Stsz :: struct {
    fullbox:        FullBox,
    sample_size:    u32be,
    sample_count:   u32be,
    entries_sizes:  []u32be
}

deserialize_stsz :: proc(data: []byte) -> (stsz: Stsz, acc: u64) {
    // Stts main values
    fullbox, fullbox_size :=  deserialize_fullbox(data[acc:])
    stsz.fullbox = fullbox
    acc += fullbox_size
    stsz.sample_size = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    stsz.sample_count = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    if stsz.sample_size == 0 {
        stsz.entries_sizes = make([]u32be, stsz.sample_count)
        for i:=0; i<int(stsz.sample_count); i+=1 {
            stsz.entries_sizes[i] = (^u32be)(&data[acc])^
            acc += size_of(u32be)
        }
    }
    return stsz, acc
}

serialize_stsz :: proc(stsz: Stsz) -> (data: []byte){
    fullbox_b := serialize_fullbox(stsz.fullbox)
    sample_count := stsz.sample_count
    sample_count_b := (^[4]byte)(&sample_count)^
    data = slice.concatenate([][]byte{fullbox_b[:], sample_count_b[:]})

    sample_size := stsz.sample_size
    sample_size_b := (^[4]byte)(&sample_size)^
    data = slice.concatenate([][]byte{data[:], sample_size_b[:]})
    entries_sizes := stsz.entries_sizes
    for i:=0;i<int(sample_count);i+=1{
        entry := entries_sizes[i]
        entry_b := (^[4]byte)(&entry)^
        data = slice.concatenate([][]byte{data[:], entry_b[:]})
    }
    // if sample_count > 0 {
    //     entries_sizes := stsz.entries_sizes
    //     entries_sizes_b := mem.ptr_to_bytes(&entries_sizes, size_of(u32be)*int(sample_count))
    //     data = slice.concatenate([][]byte{data[:], entries_sizes_b[:]})
    // }
    return data
}