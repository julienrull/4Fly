package mp4

// CopyrightBox
 Cprt :: struct { // udta -> cprt
    fullBox: FullBox,
    pad: byte, // 1 bit
    language: [3]byte, // unsigned int(5)[3]
    notice: string
}