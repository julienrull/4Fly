package mp4

import "core:mem"
import "core:slice"

// TrackRunBox
Trun :: struct { // traf -> trun
    fullbox:                FullBox,
    sample_count:           u32be,
    // the following are optional fields
    data_offset:            i32be,
    first_sample_flags:     u32be,
    // all fields in the following array are optional
    samples:                []TrackRunBoxSample
}

TrackRunBoxSample :: struct {
    sample_duration:                    u32be,
    sample_size:                        u32be,
    sample_flags:                       u32be,
    sample_composition_time_offset:     u32be,
}


deserialize_trun :: proc(data: []byte) -> (trun: Trun, acc: u64) { // TODO
    fullbox, fullbox_size := deserialize_fullbox(data)
    trun.fullbox = fullbox
    acc += fullbox_size
    trun.sample_count = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    opt1_flags := trun.fullbox.flags[0]
    is_data_offset_present := bool(opt1_flags & 0b00000001)
    is_first_sample_flags_present := bool(opt1_flags & 0b00000100)
    if is_data_offset_present {
        trun.data_offset = (^i32be)(&data[acc])^
        acc += size_of(i32be)
    }
    if is_first_sample_flags_present {
        trun.first_sample_flags = (^u32be)(&data[acc])^
        acc += size_of(u32be)
    }
    opt2_flags := trun.fullbox.flags[1]
    is_sample_duration_present := bool(opt2_flags & 0b00000001)
    is_sample_size_present := bool(opt2_flags & 0b00000010)
    is_sample_flags_present := bool(opt2_flags & 0b00000100)
    is_sample_composition_time_offsets_present := bool(opt2_flags & 0b00001000)
    trun.samples = make([]TrackRunBoxSample, trun.sample_count)
    if trun.sample_count > 0 {
        for i:=0; i < int(trun.sample_count); i+=1 {
            if is_sample_duration_present {
                trun.samples[i].sample_duration = (^u32be)(&data[acc])^
                acc = acc + size_of(u32be)
            }
            if is_sample_size_present {
                trun.samples[i].sample_size = (^u32be)(&data[acc])^
                acc = acc + size_of(u32be)
            }
            if is_sample_flags_present {
                trun.samples[i].sample_flags = (^u32be)(&data[acc])^
                acc = acc + size_of(u32be)
            }
            if is_sample_composition_time_offsets_present {
                trun.samples[i].sample_composition_time_offset = (^u32be)(&data[acc])^
                acc = acc + size_of(u32be)
            }
        }
    }
    return trun, acc
}

serialize_trun :: proc(trun: Trun) -> (data: []byte) {
    fullbox_b := serialize_fullbox(trun.fullbox)
    sample_count := tfhd.sample_count
    sample_count_b := (^[4]byte)(&sample_count)^
    data = slice.concatenate([][]byte{fullbox_b[:], sample_count_b[:]})
    opt1_flags := trun.fullbox.flags[0]
    is_data_offset_present := bool(opt1_flags & 0b00000001)
    is_first_sample_flags_present := bool(opt1_flags & 0b00000100)
    if is_data_offset_present {
        data_offset := trun.data_offset
        data_offset_b := (^[4]byte)(&data_offset)^
        data = slice.concatenate([][]byte{data[:], data_offset_b[:]})
    }
    if is_first_sample_flags_present {
        first_sample_flags := trun.first_sample_flags
        first_sample_flags_b := (^[4]byte)(&first_sample_flags)^
        data = slice.concatenate([][]byte{data[:], first_sample_flags_b[:]})
    }
    opt2_flags := trun.fullbox.flags[1]
    is_sample_duration_present := bool(opt2_flags & 0b00000001)
    is_sample_size_present := bool(opt2_flags & 0b00000010)
    is_sample_flags_present := bool(opt2_flags & 0b00000100)
    is_sample_composition_time_offsets_present := bool(opt2_flags & 0b00001000)
    if trun.sample_count > 0 {
        for i:=0; i < int(trun.sample_count); i+=1 {
            if is_sample_duration_present {
                sample_duration := trun.samples[i].sample_duration
                sample_duration_b := (^[4]byte)(&sample_duration)^
                data = slice.concatenate([][]byte{data[:], sample_duration_b[:]})
            if is_sample_size_present {
                sample_size := trun.samples[i].sample_size
                sample_size_b := (^[4]byte)(&sample_size)^
                data = slice.concatenate([][]byte{data[:], sample_size_b[:]})
            }
            if is_sample_flags_present {
                sample_flags := trun.samples[i].sample_flags
                sample_flags_b := (^[4]byte)(&sample_flags)^
                data = slice.concatenate([][]byte{data[:], sample_flags_b[:]})
            }
            if is_sample_composition_time_offsets_present {
                sample_composition_time_offset := trun.samples[i].sample_composition_time_offset
                sample_composition_time_offset_b := (^[4]byte)(&sample_composition_time_offset)^
                data = slice.concatenate([][]byte{data[:], sample_composition_time_offset_b[:]})
            }
        }
    }
    return data
}