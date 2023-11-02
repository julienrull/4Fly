package mp4

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

deserialize_tfhd :: proc(data: []byte) -> (Tfhd, u64) { // TODO
    acc: u64 = 0
    size: u64 = 0
    fullbox, fullbox_size := deserialize_fullbox(data)
    if fullbox.box.size == 1 {
        size = u64(fullbox.box.largesize)
    }else {
        size = u64(fullbox.box.size)
    }
    acc += fullbox_size
    track_ID := (^u32be)(&data[acc])^
    acc += size_of(u32be)
    base_data_offset:           u64be
    sample_description_index:   u32be
    default_sample_duration:    u32be
    default_sample_size:        u32be
    default_sample_flags:       u32be
    if size >= acc + size_of(u64be) {
        base_data_offset = (^u64be)(&data[acc])^
        acc += size_of(u64be)
         if size >= acc + size_of(u32be) {
            sample_description_index = (^u32be)(&data[acc])^
            acc += size_of(u32be)
            if size >= acc + size_of(u32be) {
                default_sample_duration = (^u32be)(&data[acc])^
                acc += size_of(u32be)
                if size >= acc + size_of(u32be) {
                    default_sample_size = (^u32be)(&data[acc])^
                    acc += size_of(u32be)
                    if size >= acc + size_of(u32be) {
                        default_sample_flags = (^u32be)(&data[acc])^
                        acc += size_of(u32be)
                    }
                }
            }
         }
    }
    return Tfhd{
        fullbox,
        track_ID,
        base_data_offset,
        sample_description_index,
        default_sample_duration,
        default_sample_size,
        default_sample_flags
    }, acc
}