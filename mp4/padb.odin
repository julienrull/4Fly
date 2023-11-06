package mp4

import "core:slice"
import "core:mem"


// PaddingBitsBox
Padb :: struct {
    fullbox:        FullBox,
    sample_count:   u32be,
    paddings:       []PaddingBitsBoxEntrie
}

PaddingBitsBoxEntrie :: struct {
     reserved:  byte, // = 0; // 1 bit
     pad1:      byte, // 3 bit
     reserved2:  byte, // = 0; // 1 bit
     pad2:      byte, // 3 bit
}

// sample_count from stsz
deserialize_padb :: proc(data: []byte) -> (padb: Padb, acc: u64) {
    fullbox, fullbox_size :=  deserialize_fullbox(data[acc:])
    acc += fullbox_size
    padb.sample_count = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    padb.paddings = make([]PaddingBitsBoxEntrie, padb.sample_count)
    for i:=0; i<int(padb.sample_count); i+=1 {
        paddings := data[acc]
        padb.paddings[i] = PaddingBitsBoxEntrie{0, (paddings >> 1) & 0b00000111, 0, (paddings >> 5) & 0b00000111}
        acc += size_of(byte)
    }
    return padb, acc
}

// sample_count from stsz
serialize_padb :: proc(padb: Padb) -> (data: []byte) {
    fullbox_b := serialize_fullbox(padb.fullbox)
    sample_count := padb.sample_count
    sample_count_b := (^[4]byte)(&sample_count)^
    data = slice.concatenate([][]byte{fullbox_b[:], sample_count_b[:]})
    for i:=0; i<int(padb.sample_count); i+=1 {
        padding_b := ([1]byte)((padb.paddings[i].pad1 << 1) | (padb.paddings[i].pad2 << 5))
        data = slice.concatenate([][]byte{data[:], padding_b[:]})
    }
    return data
}