package mp4

// MovieHeaderBox
Mvhd :: struct {  // moov -> mvhd
    fullBox:                    FullBox,
    creation_time:              u32be,
    modification_time:          u32be,
    timescale:                  u32be,
    duration:                   u32be,
    creation_time_extends:      u64be,
    modification_time_extends:  u64be,
    duration_extends:           u64be,
    rate:                       i32be,
    volume:                     i16be,
    reserved:                   i16be,
    reserved2: [2]i32be,
    matrixx: [9]i32be,
    pre_defined: [6]i32be,
    next_track_ID: u32be,
}

deserialize_mvhd :: proc(data: []byte) -> Mvhd{
    mvhd := (^Mvhd)(&data[0])^
    return mvhd
}
