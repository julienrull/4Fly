
package mp4

import "core:slice"
import "core:fmt"

// MediaDataBox
Mdat :: struct { // mdat
    box:    Box,
    data:   []byte
}

deserialize_mdat :: proc(data: []byte) -> (mdat: Mdat, acc: u64) { // TODO
    box, box_size := deserialize_box(data)
    mdat.box = box
    acc += box_size
    size: u64 = 0
    if box.size == 1 {
        size = u64(box.largesize)
    }else if box.size == 0{
        size = u64(len(data))
    }else {
        size = u64(box.size)
    }
    mdat.data = data[acc:size]
    acc += size - box_size
    return mdat, acc
}

serialize_mdat :: proc(mdat: Mdat) -> (data: []byte) { // TODO
    box_b := serialize_box(mdat.box)
    data = slice.concatenate([][]byte{box_b[:], mdat.data[:]})
    return data
}