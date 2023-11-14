package mp4

import "core:mem"
import "core:slice"

// VideoMediaHeaderBox
Vmhd :: struct { // minf -> vmhd
    fullbox:        FullBox,
    graphicsmode:   u16be, // copy, see below
    opcolor:        [3]u16be,
}


deserialize_vmhd :: proc(data: []byte) -> (vmhd: Vmhd, acc: u64) {
    fullbox, fullbox_size := deserialize_fullbox(data[acc:])
    vmhd.fullbox = fullbox
    acc += fullbox_size
    vmhd.graphicsmode = (^u16be)(&data[acc])^
    acc += size_of(u16be)
    vmhd.opcolor = (^[3]u16be)(&data[acc])^
    acc += size_of([3]u16be)
    return vmhd, acc
}

serialize_vmhd :: proc(vmhd: Vmhd) -> (data: []byte) {
    fullbox_b := serialize_fullbox(vmhd.fullbox)
    graphicsmode := vmhd.graphicsmode
    graphicsmode_b := (^[2]byte)(&graphicsmode)^
    data = slice.concatenate([][]byte{fullbox_b[:], graphicsmode_b[:]})
    opcolor := vmhd.opcolor
    opcolor_b := (^[6]byte)(&opcolor)^
    data = slice.concatenate([][]byte{data[:], opcolor_b[:]})
    return data
}