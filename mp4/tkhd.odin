package mp4

// TrackHeaderBox
Tkhd :: struct { // trak -> tkhd
    fullBox:                    FullBox,
    creation_time:              u32be,
    creation_time_extends:      u64be,
    modification_time:          u32be,
    modification_time_extends:  u64be,
    track_ID:                   u32be,
    reserved:                   u32be,
    duration:                   u32be,
    duration_extends:           u64be,

    reserved2:                  [2]u32be,
    layer:                      i16be,
    alternate_group:            i16be,
    volume:                     i16be,
    reserved3:                  u16be,
    matrixx:                    [9]i32be,
    width:                      u32be,
    height:                     u32be,
}

deserialize_tkhd  :: proc(data: []byte) -> Tkhd{
    track := (^Tkhd)(&data[0])^
    return track
}