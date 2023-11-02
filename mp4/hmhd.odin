package mp4

// HintMediaHeaderBox
Hmhd :: struct { // minf -> hmhd
    fullBox:    FullBox,
    maxPDUsize: u16be,
    avgPDUsize: u16be,
    maxbitrate: u32be,
    avgbitrate: u32be,
    reserved:   u32be
}