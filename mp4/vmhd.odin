package mp4

// VideoMediaHeaderBox
Vmhd :: struct { // minf -> vmhd
    fullBox:        FullBox,
    graphicsmode:   u16be, // copy, see below
    opcolor:        [3]u16be,
}