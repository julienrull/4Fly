package mp4

import "core:slice"
import "core:mem"

// CopyrightBox
 Cprt :: struct { // udta -> cprt
    fullbox: FullBox,
    pad: byte, // = 0 1 bit
    language: [3]byte, // unsigned int(5)[3]
    notice: []byte // string
}

deserialize_cprt :: proc(data: []byte) -> (cprt: Cprt, acc: u64) {
    fullbox, fullbox_size :=  deserialize_fullbox(data[acc:])
    cprt.fullbox = fullbox
    acc += fullbox_size
    cprt.pad = 0
    pack: u16be = (^u16be)(&data[acc])^
    cprt.language[0] = byte((pack >> 1) & 0b00000000_00011111)
    cprt.language[1] = byte((pack >> 6) & 0b00000000_00011111)
    cprt.language[2] = byte((pack >> 11) & 0b00000000_00011111)
    acc += size_of(u16be)
    remain :=  u64(fullbox.box.size) - acc
    cprt.notice = mem.ptr_to_bytes(&data[acc], int(remain))
    return cprt, acc
}

serialize_cprt :: proc(cprt: Cprt) -> (data: []byte) {
    fullbox_b := serialize_fullbox(cprt.fullbox)
    pack: u16be = u16be((u16be(cprt.language[2]) << 11) | (u16be(cprt.language[1]) << 6) | (u16be(cprt.language[0]) << 1))
    pack_b := (^[2]byte)(&pack)^
    data = slice.concatenate([][]byte{fullbox_b[:], pack_b[:]})
    data = slice.concatenate([][]byte{data[:], cprt.notice[:]})
    return data
}