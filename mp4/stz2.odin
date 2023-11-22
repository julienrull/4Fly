package mp4

import "core:slice"
import "core:mem"

// SampleSizeBox
Stz2 :: struct {
    fullbox:        FullBox,
    reserved: [3]byte, // = 0
    field_size:    byte,
    sample_count:   u32be,
    entries_sizes:  []byte
}

deserialize_stz2 :: proc(data: []byte) -> (stz2: Stz2, acc: u64) {
    // Stts main values
    fullbox, fullbox_size :=  deserialize_fullbox(data[acc:])
    stz2.fullbox = fullbox
    acc += fullbox_size
    stz2.reserved = (^[3]byte)(&data[acc])^
    acc += size_of([3]byte)
    stz2.field_size = (^byte)(&data[acc])^
    acc += size_of(byte)
    stz2.sample_count = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    nb_byte := int(stz2.field_size) / 8 < 1 ? 1 * int(stz2.sample_count) : int(stz2.field_size) / 8 * int(stz2.sample_count)
    stz2.entries_sizes = data[acc:nb_byte]
    acc += u64(nb_byte)
    return stz2, acc
}

serialize_stz2 :: proc(stz2: Stz2) -> (data: []byte){
    fullbox_b := serialize_fullbox(stz2.fullbox)
    reserved := stz2.reserved
    data = slice.concatenate([][]byte{fullbox_b[:], reserved[:]})

    field_size := stz2.field_size
    field_size_b := (^[1]byte)(&field_size)^
    data = slice.concatenate([][]byte{data[:], field_size_b[:]})

    sample_count := stz2.sample_count
    sample_count_b := (^[4]byte)(&sample_count)^
    data = slice.concatenate([][]byte{data[:], sample_count_b[:]})

    if sample_count > 0 {
        data = slice.concatenate([][]byte{data[:], stz2.entries_sizes[:]})
    }
    return data
}