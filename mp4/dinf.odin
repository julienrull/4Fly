package mp4

import "core:slice"

// DataInformationBox
Dinf :: struct { // minf -> dinf
    box:    Box,
    dref: Dref
}

deserialize_dinf :: proc(data: []byte) -> (dinf: Dinf, acc: u64) {
    box, box_size := deserialize_box(data[acc:])
    dinf.box = box
    acc += box_size
    dref, dref_size := deserialize_dref(data[acc:])
    dinf.dref = dref
    acc += dref_size
    return dinf, acc
}

serialize_dinf :: proc(dinf: Dinf) -> (data: []byte) {
    box_b := serialize_box(dinf.box)
    dref_b := serialize_dref(dinf.dref)
    data = slice.concatenate([][]byte{box_b[:], dref_b[:]})    
    return data
}