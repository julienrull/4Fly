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
            case "tfhd":
                tfhd, tfhd_size := deserialize_tfhd(data[acc:])
                traf.tfhd = tfhd
                acc += tfhd_size
            case "tfdt":
                tfdt, tfdt_size := deserialize_tfdt(data[acc:])
                traf.tfdt = tfdt
                acc += tfdt_size
            case "trun":
                trun, trun_size := deserialize_trun(data[acc:])
                traf.trun = trun
                acc += trun_size
            case:
                panic("moov sub box not implemented")
        }
        if acc < size {
            sub_box, sub_box_size = deserialize_box(data[acc:])
            name = to_string(&sub_box.type)
        }
    }

    return traf, acc
}

serialize_traf :: proc(traf: Traf) -> (data: []byte) {
    box_b := serialize_box(traf.box)
    data = box_b
    name := traf.tfhd.fullbox.box.type
    if to_string(&name) == "tfhd" {
        tfhd_b := serialize_tfhd(traf.tfhd)
        data = slice.concatenate([][]byte{data[:], tfhd_b[:]})
    }

    name = traf.tfdt.fullbox.box.type
    if to_string(&name) == "tfdt" {
        tfdt_b := serialize_tfdt(traf.tfdt)
        data = slice.concatenate([][]byte{data[:], tfdt_b[:]})
    }

    name = traf.trun.fullbox.box.type
    if to_string(&name) == "trun" {
        trun_b := serialize_trun(traf.trun)
        data = slice.concatenate([][]byte{data[:], trun_b[:]})
    }
    



    return data
}