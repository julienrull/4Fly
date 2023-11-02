package mp4


// MovieBox
Moov :: struct { // moov
    box:            Box,
    movieHeaderBox: Mvhd,
    traks:          []Trak,
    udta: Udta
}