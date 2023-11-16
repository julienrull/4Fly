package mp4

import "core:slice"
import "core:fmt"

// EditBox
Edts :: struct { // trak -> edts
    box:    Box,
    elst:   Elst,
}

deserialize_edts :: proc(data: []byte) -> (edts: Edts, acc: u64) {
    box, box_size :=  deserialize_box(data[acc:])
    acc += box_size
    edts.box = box
    elst, elst_size := deserialize_elst(data[acc:])
    edts.elst = elst
    acc += elst_size
    return edts, acc
}

serialize_edts :: proc(edts: Edts) -> (data: []byte) {
    box_b := serialize_box(edts.box)
    elst_b := serialize_elst(edts.elst)
    data = slice.concatenate([][]byte{box_b[:], elst_b[:]})
    return data
}