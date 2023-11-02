package mp4

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

deserialize_trun :: proc(data: []byte) -> (Trun, u64) { // TODO
    acc: u64 = 0
    size: u64 = 0
    fullbox, fullbox_size := deserialize_fullbox(data)
    if fullbox.box.size == 1 {
        size = u64(fullbox.box.largesize)
    }else {
        size = u64(fullbox.box.size)
    }
    acc += fullbox_size
    sample_count: u32be = (^u32be)(&data[acc])^
    acc = acc + size_of(u32be)
    data_offset:            i32be
    first_sample_flags:     u32be
    if size >= acc + size_of(u32be) {
        data_offset = (^i32be)(&data[acc])^
        acc = acc + size_of(u32be)
        if size >= acc + size_of(u32be) {
            first_sample_flags = (^u32be)(&data[acc])^
            acc = acc + size_of(u32be)
        }
    }
    samples := make([]TrackRunBoxSample, sample_count)
    for i:=0; i < int(sample_count); i+=1 {
        samples[i].sample_duration                    = (^u32be)(&data[acc])^
        acc = acc + size_of(u32be)
        samples[i].sample_size                        = (^u32be)(&data[acc])^
        acc = acc + size_of(u32be)
        samples[i].sample_flags                       = (^u32be)(&data[acc])^
        acc = acc + size_of(u32be)
        samples[i].sample_composition_time_offset     = (^u32be)(&data[acc])^
        acc = acc + size_of(u32be)
    }
    return Trun{
        fullbox,
        sample_count,
        data_offset,
        first_sample_flags,
        samples
    }, acc
}
