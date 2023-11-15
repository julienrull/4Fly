package mp4

import "core:slice"

// MediaDataBox
Mdat :: struct { // mdat
    box:    Box,
    //data:   []byte
}

deserialize_mdat :: proc(data: []byte) -> (Mdat, u64) { // TODO
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
    //mdat_data := data[box_size:]
    acc += (size - box_size)

    return Mdat{
        box,
        //mdat_data
    }, acc
}

serialize_mdat :: proc(mdat: Mdat) -> ([]byte) { // TODO
    box_b := serialize_box(mdat.box)
    return box_b
}