package mp4

// MovieFragmentHeaderBox
Mfhd :: struct { // moof -> mfhd
    fullbox:            FullBox,
    sequence_number:    u32be
}

deserialize_mfhd :: proc(data: []byte) -> (Mfhd, u64) { // TODO
    fullbox, fullbox_size := deserialize_fullbox(data)
    return Mfhd{fullbox, (^u32be)(&data[fullbox_size])^}, fullbox_size + size_of(u32be)
}