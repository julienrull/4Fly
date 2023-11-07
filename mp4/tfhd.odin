package mp4

import "core:mem"
import "core:slice"

// TrackFragmentHeaderBox
Tfhd :: struct { // traf -> tfhd
    fullbox:                    FullBox,
    track_ID:                   u32be,
    // all the following are optional fields
    base_data_offset:           u64be,
    sample_description_index:   u32be,
    default_sample_duration:    u32be,
    default_sample_size:        u32be,
    default_sample_flags:       u32be
}

deserialize_tfhd :: proc(data: []byte) -> (tfhd: Tfhd, acc: u64) { // TODO
    fullbox, fullbox_size := deserialize_fullbox(data)
    tfhd.fullbox = fullbox
    acc += fullbox_size
    tfhd.track_ID = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    opt1_flags := tfhd.fullbox.flags[0]
    opt3_flags := tfhd.fullbox.flags[2]
    is_base_data_offset_present := bool(opt1_flags & 0b00000001)
    is_sample_description_index_present := bool(opt1_flags & 0b00000010)
    is_default_sample_duration_present := bool(opt1_flags & 0b00001000)
    is_default_sample_size_present := bool(opt1_flags & 0b00010000)
    is_default_sample_flags_present  := bool(opt1_flags & 0b00100000)
    duration_is_empty := bool(opt3_flags & 0b00000001)
    if is_base_data_offset_present {
        tfhd.base_data_offset = (^u64be)(&data[acc])^
        acc += size_of(u64be)
    }
    if is_sample_description_index_present {
        tfhd.sample_description_index = (^u32be)(&data[acc])^
        acc += size_of(u32be)
    }
    if is_default_sample_duration_present {
        tfhd.default_sample_duration = (^u32be)(&data[acc])^
        acc += size_of(u32be)
    }
    if is_default_sample_size_present {
        tfhd.default_sample_size = (^u32be)(&data[acc])^
        acc += size_of(u32be)
    }
    if is_default_sample_flags_present {
        tfhd.default_sample_flags = (^u32be)(&data[acc])^
        acc += size_of(u32be)
    }
    // if duration_is_empty {

    // }
    return tfhd, acc
}

serialize_tfhd :: proc(tfhd: Tfhd) -> (data: []byte) {
    fullbox_b := serialize_fullbox(tfhd.fullbox)
    track_ID := tfhd.track_ID
    track_ID_b := (^[4]byte)(&track_ID)^
    data = slice.concatenate([][]byte{fullbox_b[:], track_ID_b[:]})
    opt1_flags := tfhd.fullbox.flags[0]
    opt3_flags := tfhd.fullbox.flags[2]
    is_base_data_offset_present := bool(opt1_flags & 0b00000001)
    is_sample_description_index_present := bool(opt1_flags & 0b00000010)
    is_default_sample_duration_present := bool(opt1_flags & 0b00001000)
    is_default_sample_size_present := bool(opt1_flags & 0b00010000)
    is_default_sample_flags_present  := bool(opt1_flags & 0b00100000)
    duration_is_empty := bool(opt3_flags & 0b00000001)
    if is_base_data_offset_present {
        base_data_offset := tfhd.base_data_offset
        base_data_offset_b := (^[8]byte)(&base_data_offset)^
        data = slice.concatenate([][]byte{data[:], base_data_offset_b[:]})
    }
    if is_sample_description_index_present {
        sample_description_index := tfhd.sample_description_index
        sample_description_index_b := (^[4]byte)(&sample_description_index)^
        data = slice.concatenate([][]byte{data[:], sample_description_index_b[:]})
    }
    if is_default_sample_duration_present {
        default_sample_duration := tfhd.default_sample_duration
        default_sample_duration_b := (^[4]byte)(&default_sample_duration)^
        data = slice.concatenate([][]byte{data[:], default_sample_duration_b[:]})
    }
    if is_default_sample_size_present {
        default_sample_size := tfhd.default_sample_size
        default_sample_size_b := (^[4]byte)(&default_sample_size)^
        data = slice.concatenate([][]byte{data[:], default_sample_size_b[:]})
    }
    if is_default_sample_flags_present {
        default_sample_flags := tfhd.default_sample_flags
        default_sample_flags_b := (^[4]byte)(&default_sample_flags)^
        data = slice.concatenate([][]byte{data[:], default_sample_flags_b[:]})
    }
    // if duration_is_empty {

    // }
    return data
}