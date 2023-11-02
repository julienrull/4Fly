package mp4


// MovieFragmentBox
Moof :: struct { // moof
    box:        Box,
    mfhd:       Mfhd,
    trafs:      [dynamic]Traf
}

deserialize_moof :: proc(data: []byte) -> (Moof, u64) { // TODO
    acc: u64 = 0
    size: u64 = 0
    box, box_size := deserialize_box(data)
    if box.size == 1 {
        size = u64(box.largesize)
    }else if box.size == 0{
        size = u64(len(data))
    }else {
        size = u64(box.size)
    }
    acc += box_size
    mfhd, mfhd_size := deserialize_mfhd(data[acc:])
    acc += mfhd_size
    trafs := make([dynamic]Traf, 0, 16)
    traf_box, traf_box_size := deserialize_box(data[acc:])
    name := to_string(&traf_box.type)
    for name == "traf" {
        traf, traf_size := deserialize_traf(data[acc:])
        append(&trafs, traf)
        acc += traf_size
        traf_box, traf_box_size = deserialize_box(data[acc:])
        name = to_string(&traf_box.type)
    }
    return Moof{box, mfhd, trafs}, acc
}