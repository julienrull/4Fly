package mp4

import "core:mem"
import "core:slice"

// MovieFragmentBox
Moof :: struct { // moof
    box:        Box,
    mfhd:       Mfhd,
    trafs:      [dynamic]Traf
}

deserialize_moof :: proc(data: []byte) -> (moof: Moof, acc: u64) {
    box, box_size := deserialize_box(data)
    moof.box = box
    acc += box_size
    mfhd, mfhd_size := deserialize_mfhd(data[acc:])
    moof.mfhd = mfhd
    acc += mfhd_size
    moof.trafs = make([dynamic]Traf, 0, 16)
    traf_box, traf_box_size := deserialize_box(data[acc:])
    name := to_string(&traf_box.type)
    for name == "traf" {
        traf, traf_size := deserialize_traf(data[acc:])
        append(&moof.trafs, traf)
        acc += traf_size
        traf_box, traf_box_size = deserialize_box(data[acc:])
        name = to_string(&traf_box.type)
    }
    return moof, acc
}

serialize_moof :: proc(moof: Moof) -> (data: []byte) {
    box_b := serialize_box(moof.box)
    mfhd_b := serialize_mfhd(moof.mfhd)
    data = slice.concatenate([][]byte{box_b[:], mfhd_b[:]})
    for i:=0; i<len(moof.trafs); i+=1 {
        traf_b := serialize_traf(moof.trafs[i])
        data = slice.concatenate([][]byte{data[:], traf_b[:]})
    }
    return data
}