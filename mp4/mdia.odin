package mp4

import "core:slice"
import "core:fmt"

// MediaBox
Mdia :: struct { // trak -> mdia
    box:    Box,
    mdhd:   Mdhd,
    hdlr:   Hdlr,
    minf:   Minf
}

deserialize_mdia :: proc(data: []byte) -> (mdia: Mdia, acc: u64) {
    box, box_size := deserialize_box(data)
    mdia.box = box
    acc += box_size
    size: u64
    if box.size == 1 {
        size = u64(box.largesize)
    }else if box.size == 0 {
        size = u64(len(data))
    }else {
        size =  u64(box.size)
    }
    sub_box, sub_box_size := deserialize_box(data[acc:])
    name := to_string(&sub_box.type)
    for  acc < size {
        switch name {
            case "mdhd":
                atom, atom_size := deserialize_mdhd(data[acc:])
                mdia.mdhd = atom
                acc += atom_size
            case "hdlr":
                atom, atom_size := deserialize_hdlr(data[acc:])
                mdia.hdlr = atom
                acc += atom_size
            case "minf": // TODO: case if minf is found before hdlr
                atom, atom_size := deserialize_minf(data[acc:], mdia.hdlr.handler_type)
                mdia.minf = atom
                acc += atom_size
            case:
                panic("mdia sub box not implemented")
        }
        if acc < size {
            sub_box, sub_box_size = deserialize_box(data[acc:])
            name = to_string(&sub_box.type)
        }
    }
    return mdia, acc
}

serialize_mdia :: proc(mdia: Mdia) -> (data: []byte) {
    box_b := serialize_box(mdia.box)
    data = slice.concatenate([][]byte{[]byte{}, box_b[:]})
    name := mdia.mdhd.fullbox.box.type
    if to_string(&name) == "mdhd" {
        bin := serialize_mdhd(mdia.mdhd)
        data = slice.concatenate([][]byte{data[:], bin[:]})
    }
    name = mdia.hdlr.fullbox.box.type
    if to_string(&name) == "hdlr" {
        bin := serialize_hdlr(mdia.hdlr)
        data = slice.concatenate([][]byte{data[:], bin[:]})
    }
    name = mdia.minf.box.type
    if to_string(&name) == "minf" {
        bin := serialize_minf(mdia.minf, mdia.hdlr.handler_type)
        data = slice.concatenate([][]byte{data[:], bin[:]})
    }
    return data
}