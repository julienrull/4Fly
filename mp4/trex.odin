package mp4

import "core:mem"
import "core:slice"

// TrackExtendsBox
Trex :: struct {
    fullbox                            : FullBox,
    track_ID                           : u32be,
    default_sample_description_index   : u32be,
    default_sample_duration            : u32be,
    default_sample_size                : u32be,
    default_sample_flags               : u32be,
}

deserialize_trex :: proc(data: []byte) -> (trex: Trex, acc: u64) {
    fullbox, fullbox_size := deserialize_fullbox(data[acc:])
    trex.fullbox = fullbox
    acc += fullbox_size
    trex.track_ID = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    trex.default_sample_description_index = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    trex.default_sample_duration = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    trex.default_sample_size = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    trex.default_sample_flags = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    return trex, acc
}

serialize_trex :: proc(trex: Trex) -> (data: []byte) {
    fullbox_b := serialize_fullbox(trex.fullbox)
    track_ID := trex.track_ID
    track_ID_b := (^[4]byte)(&track_ID)^
    data = slice.concatenate([][]byte{fullbox_b[:], track_ID_b[:]})

    default_sample_description_index := trex.default_sample_description_index
    default_sample_description_index_b := (^[4]byte)(&default_sample_description_index)^
    data = slice.concatenate([][]byte{data[:], default_sample_description_index_b[:]})

    default_sample_duration := trex.default_sample_duration
    default_sample_duration_b := (^[4]byte)(&default_sample_duration)^
    data = slice.concatenate([][]byte{data[:], default_sample_duration_b[:]})

    default_sample_size := trex.default_sample_size
    default_sample_size_b := (^[4]byte)(&default_sample_size)^
    data = slice.concatenate([][]byte{data[:], default_sample_size_b[:]})

    default_sample_flags := trex.default_sample_flags
    default_sample_flags_b := (^[4]byte)(&default_sample_flags)^
    data = slice.concatenate([][]byte{data[:], default_sample_flags_b[:]})

    return data
}
