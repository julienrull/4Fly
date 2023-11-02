package mp4

FullBox :: struct {
    box:        Box,
    version:    u8,
    flags:      [3]byte,
}

deserialize_fullbox :: proc(data: []byte) ->( FullBox, u64) {
    acc: u64 = 0
    box, box_size := deserialize_box(data)
    acc = acc + box_size
    version := (^u8)(&data[acc])^
    acc = acc + size_of(u8)
    flags := (^[3]byte)(&data[acc])^
    acc = acc + size_of([3]byte)
    return FullBox{box, version, flags}, acc
}