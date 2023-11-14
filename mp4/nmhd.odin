package mp4

// NullMediaHeaderBox
Nmhd :: struct { // minf -> nmhd
    fullbox:    FullBox,
}

deserialize_nmhd :: proc(data: []byte) -> (nmhd: Nmhd, acc: u64) {
    fullbox, fullbox_size := deserialize_fullbox(data[acc:])
    nmhd.fullbox = fullbox
    acc += fullbox_size
    return nmhd, acc
}

serialize_nmhd :: proc(nmhd: Nmhd) -> (data: []byte) {
    data = serialize_fullbox(nmhd.fullbox)
    return data
}