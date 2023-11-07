package mp4

import "core:slice"
import "core:mem"

//UserDataBox
Udta :: struct{ // moov -> udta
    box:    Box,
    cprt:   Cprt
}

deserialize_udta :: proc(data: []byte) -> (udta: Udta, acc: u64) {
    box, box_size :=  deserialize_box(data[acc:])
    acc += box_size
    udta.box = box
    cprt, cprt_size := deserialize_cprt(data[acc:])
    udta.cprt = cprt
    acc += cprt_size
    return udta, acc
}

serialize_udta :: proc(udta: Udta) -> (data: []byte) {
    box_b := serialize_box(udta.box)
    cprt_b := serialize_cprt(udta.cprt)
    data = slice.concatenate([][]byte{box_b[:], cprt_b[:]})
    return data
}