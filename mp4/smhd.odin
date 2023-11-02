package mp4

// SoundMediaHeaderBox
Smhd :: struct { // minf -> smhd
    fullBox:    FullBox,
    balance:    i16be,
    reserved:   u16be
}