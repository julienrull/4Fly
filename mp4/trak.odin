package mp4

// TrackBox
Trak :: struct { // moov -> trak
    box:    Box,
    tkhd:   Tkhd,
    mdias:   []Mdia,
    edtss:   []Edts,
}