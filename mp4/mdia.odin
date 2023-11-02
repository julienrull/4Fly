package mp4

// MediaBox
Mdia :: struct { // trak -> mdia
    box:    Box,
    mdhd:   Mdhd,
    hdlr:   Hdlr,
    minf:   Minf
}
