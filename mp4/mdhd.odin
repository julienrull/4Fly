package mp4

// MediaHeaderBox
Mdhd :: struct { // mdia -> mdhd
    fullBox:                    FullBox,
    creation_time:              u32be,
    creation_time_extends:      u64be,
    modification_time:          u32be,
    modification_time_extends:  u64be,
    timescale:                  u32be,
    duration:                   u32be,
    duration_extends:           u64be,

    pad:                    byte, // ! 1 bit 
    language:               [3]u8, // unsigned int(5)[3]
    pre_defined:            u16be
}