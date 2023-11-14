package mp4

import "core:mem"
import "core:slice"

// HintMediaHeaderBox
Hmhd :: struct { // minf -> hmhd
    fullbox:    FullBox,
    maxPDUsize: u16be,
    avgPDUsize: u16be,
    maxbitrate: u32be,
    avgbitrate: u32be,
    reserved:   u32be
}

deserialize_hmhd :: proc(data: []byte) -> (hmhd: Hmhd, acc: u64) {
    fullbox, fullbox_size := deserialize_fullbox(data[acc:])
    hmhd.fullbox = fullbox
    acc += fullbox_size
    hmhd.maxPDUsize = (^u16be)(&data[acc])^
    acc += size_of(u16be)
    hmhd.avgPDUsize = (^u16be)(&data[acc])^
    acc += size_of(u16be)
    hmhd.maxbitrate = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    hmhd.avgbitrate = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    hmhd.reserved = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    return hmhd, acc
}

serialize_hmhd :: proc(hmhd: Hmhd) -> (data: []byte) {
    fullbox_b := serialize_fullbox(hmhd.fullbox)
    maxPDUsize := hmhd.maxPDUsize
    maxPDUsize_b := (^[2]byte)(&maxPDUsize)^
    data = slice.concatenate([][]byte{fullbox_b[:], maxPDUsize_b[:]})
    avgPDUsize := hmhd.avgPDUsize
    avgPDUsize_b := (^[2]byte)(&avgPDUsize)^
    data = slice.concatenate([][]byte{data[:], avgPDUsize_b[:]})

    maxbitrate := hmhd.maxbitrate
    maxbitrate_b := (^[2]byte)(&maxbitrate)^
    data = slice.concatenate([][]byte{data[:],  maxbitrate_b[:]})

    avgbitrate := hmhd.avgbitrate
    avgbitrate_b := (^[4]byte)(&avgbitrate)^
    data = slice.concatenate([][]byte{data[:], avgbitrate_b[:]})

    reserved := hmhd.reserved
    reserved_b := (^[2]byte)(&reserved)^
    data = slice.concatenate([][]byte{data[:], reserved_b[:]})

    data = slice.concatenate([][]byte{data[:], reserved_b[:]})
    return data
}