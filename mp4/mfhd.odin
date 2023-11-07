package mp4

import "core:mem"
import "core:slice"

// MovieFragmentHeaderBox
Mfhd :: struct { // moof -> mfhd
    fullbox:            FullBox,
    sequence_number:    u32be
}

deserialize_mfhd :: proc(data: []byte) -> (mfhd: Mfhd, acc: u64) { // TODO
    fullbox, fullbox_size := deserialize_fullbox(data)
    mfhd.fullbox = fullbox
    acc += fullbox_size
    mfhd.sequence_number = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    return mfhd, acc
}

serialize_mfhd :: proc(mfhd: Mfhd) -> (data: []byte) {
    fullbox_b := serialize_fullbox(mfhd.fullbox)
    sequence_number := mfhd.sequence_number
    sequence_number_b := (^[4]byte)(&sequence_number)^
    data = slice.concatenate([][]byte{fullbox_b[:], sequence_number_b[:]})
    return data
}