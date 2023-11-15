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
    moof.trafs = make([dynamic]Traf, 0, 16)
    box, box_size := deserialize_box(data)
    moof.box = box
    acc += box_size
    sub_box, sub_box_size := deserialize_box(data[acc:])
    name := to_string(&sub_box.type)
    for  acc < u64(box.size) {
        switch name {
            case "mfhd":
                mfhd, mfhd_size := deserialize_mfhd(data[acc:])
                moof.mfhd = mfhd
                acc += mfhd_size
            case "traf":
                traf, traf_size := deserialize_traf(data[acc:])
                append(&moof.trafs, traf)
                acc += traf_size
            case:
                panic("moov sub box not implemented")
        }
        sub_box, sub_box_size = deserialize_box(data[acc:])
        name := to_string(&sub_box.type)
    }
    
    return moof, acc
}

serialize_moof :: proc(moof: Moof) -> (data: []byte) {
    box_b := serialize_box(moof.box)
    name := moof.mfhd.fullbox.box.type
    if to_string(&name) == "mvhd" {
        bin := serialize_mfhd(moof.mfhd)
        data = slice.concatenate([][]byte{data[:], bin[:]})
    }
    if len(moof.trafs) > 0 {
        for i:=0; i<len(moof.trafs); i+=1 {
            traf_b := serialize_traf(moof.trafs[i])
            data = slice.concatenate([][]byte{data[:], traf_b[:]})
        }
    }
    return data
}