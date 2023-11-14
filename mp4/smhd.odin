package mp4

import "core:mem"
import "core:slice"

// SoundMediaHeaderBox
Smhd :: struct { // minf -> smhd
    fullbox:    FullBox,
    balance:    i16be,
    reserved:   u16be
}


deserialize_smhd :: proc(data: []byte) -> (smhd: Smhd, acc: u64) {
    fullbox, fullbox_size := deserialize_fullbox(data[acc:])
    smhd.fullbox = fullbox
    acc += fullbox_size
    smhd.balance = (^i16be)(&data[acc])^
    acc += size_of(i16be)
    smhd.reserved = (^u16be)(&data[acc])^
    acc += size_of(u16be)
    return smhd, acc
}

serialize_smhd :: proc(smhd: Smhd) -> (data: []byte) {
    fullbox_b := serialize_fullbox(smhd.fullbox)
    balance := smhd.balance
    balance_b := (^[2]byte)(&balance)^
    data = slice.concatenate([][]byte{fullbox_b[:], balance_b[:]})
    reserved := smhd.reserved
    reserved_b := (^[2]byte)(&reserved)^
    data = slice.concatenate([][]byte{data[:], reserved_b[:]})
    return data
}