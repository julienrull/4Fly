package mp4

import "core:mem"
import "core:slice"

// TrackFragmentBox
Traf :: struct { // moof -> traf
    box:    Box,
    tfhd:   Tfhd,
    tfdt:   Tfdt,
    trun:   Trun
}

deserialize_traf :: proc(data: []byte) -> (traf: Traf, acc: u64) {
    box, box_size := deserialize_box(data)
    traf.box = box
    acc += box_size
    tfhd, tfhd_size := deserialize_tfhd(data[box_size:])
    traf.tfhd = tfhd
    acc += tfhd_size
    tfdt, tfdt_size := deserialize_tfdt(data[box_size:])
    traf.tfdt = tfdt
    acc += tfdt_size
    trun, trun_size := deserialize_trun(data[box_size + tfhd_size:])
    traf.trun = trun
    acc += trun_size
    return traf, acc
}

serialize_traf :: proc(traf: Traf) -> (data: []byte) {
    box_b := serialize_box(traf.box)
    tfhd_b := serialize_tfhd(traf.tfhd)
    data = slice.concatenate([][]byte{box_b[:], tfhd_b[:]})
    tfdt_b := serialize_tfdt(traf.tfdt)
    data = slice.concatenate([][]byte{data[:], tfdt_b[:]})
    trun_b := serialize_trun(traf.trun)
    data = slice.concatenate([][]byte{data[:], trun_b[:]})
    return data
}