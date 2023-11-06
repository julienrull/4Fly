package mp4

import "core:slice"
import "core:mem"


// ShadowSyncSampleBox
Stdp :: struct {
    fullbox: FullBox,
    priorities: []u16be
}

// sample_count from stsz
deserialize_stdp :: proc(data: []byte, sample_count: u32be) -> (stdp: Stdp, acc: u64) {
    fullbox, fullbox_size :=  deserialize_fullbox(data[acc:])
    acc += fullbox_size
    stdp.priorities = make([]u16be, sample_count)
    for i:=0; i<int(sample_count); i+=1 {
        stdp.priorities[i] = (^u16be)(&data[acc])^
        acc += size_of(u16be)
    }
    return stdp, acc
}

// sample_count from stsz
serialize_stdp :: proc(stdp: Stdp, sample_count: u32be) -> (data: []byte) {
    fullbox_b := serialize_fullbox(stdp.fullbox)
    data = slice.concatenate([][]byte{fullbox_b[:], []u8{}})
    if sample_count > 0 {
        priorities := stdp.priorities[:]
        priorities_b := mem.ptr_to_bytes(&priorities, size_of(u16be) * int(sample_count))
        data = slice.concatenate([][]byte{data[:], priorities_b[:]})
    }
    return data
}