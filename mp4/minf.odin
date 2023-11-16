package mp4

import "core:slice"
import "core:fmt"

// MediaInformationBox
Minf :: struct { // mdia -> minf
    box:    Box,
    
    vmhd:   Vmhd,
    smhd:   Smhd,
    hmhd:   Hmhd,
    nmhd:   Nmhd,

    dinf: Dinf,
    stbl: Stbl
}

deserialize_minf :: proc(data: []byte, handle_type: u32be) -> (minf: Minf, acc: u64) {
    box, box_size := deserialize_box(data[acc:])
    minf.box = box
    acc += box_size
    sub_box, sub_box_size := deserialize_box(data[acc:])
    name := to_string(&sub_box.type)
    for  acc < u64(box.size) {
        switch name {
            case "vmhd":
                atom, atom_size := deserialize_vmhd(data[acc:])
                minf.vmhd = atom
                acc += atom_size
            case "smhd":
                atom, atom_size := deserialize_smhd(data[acc:])
                minf.smhd = atom
                acc += atom_size
            case "hmhd":
                atom, atom_size := deserialize_hmhd(data[acc:])
                minf.hmhd = atom
                acc += atom_size
            case "dinf":
                atom, atom_size := deserialize_dinf(data[acc:])
                minf.dinf = atom
                acc += atom_size
            case "stbl":
                stbl, stbl_size := deserialize_stbl(data[acc:], handle_type)
                minf.stbl = stbl
                acc += stbl_size
            case:
                nmhd, nmhd_size := deserialize_nmhd(data[acc:])
                minf.nmhd = nmhd
                acc += nmhd_size
        }
        sub_box, sub_box_size = deserialize_box(data[acc:])
        name := to_string(&sub_box.type)
    }

    



    return minf, acc
}

serialize_minf :: proc(minf: Minf, handle_type: u32be) -> (data: []byte) {
    box_b := serialize_box(minf.box)
    type := minf.vmhd.fullbox.box.type
    vmhd_s := to_string(&type)

    type = minf.smhd.fullbox.box.type
    smhd_s := to_string(&type)

    type = minf.hmhd.fullbox.box.type
    hmhd_s := to_string(&type)

    type = minf.nmhd.fullbox.box.type
    nmhd_s := to_string(&type)
    
    if vmhd_s == "vmhd" {
        vmhd_b := serialize_vmhd(minf.vmhd)    
        data = slice.concatenate([][]byte{box_b[:], vmhd_b[:]})
    }
    if smhd_s == "smhd" {
        smhd_b := serialize_smhd(minf.smhd)    
        data = slice.concatenate([][]byte{box_b[:], smhd_b[:]})
    }
    if hmhd_s == "hmhd" {
        hmhd_b := serialize_hmhd(minf.hmhd)    
        data = slice.concatenate([][]byte{box_b[:], hmhd_b[:]})
    }
    if nmhd_s == "nmhd" {
        nmhd_b := serialize_nmhd(minf.nmhd)    
        data = slice.concatenate([][]byte{box_b[:], nmhd_b[:]})
    }
    
    dinf_b := serialize_dinf(minf.dinf)
    data = slice.concatenate([][]byte{data[:], dinf_b[:]})

    stbl_b := serialize_stbl(minf.stbl, handle_type)
    data = slice.concatenate([][]byte{data[:], stbl_b[:]})
    return data
}



