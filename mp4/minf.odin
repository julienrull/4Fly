package mp4

import "core:slice"

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

deserialize_minf :: proc(data: []byte) -> (minf: Minf, acc: u64) {
    box, box_size := deserialize_box(data[acc:])
    minf.box = box
    acc += box_size
    sub_box, sub_box_size := deserialize_box(data[acc:])
    type_s := to_string(&box.type)
    switch type_s {
        case "vmhd":
            vmhd, vmhd_size := deserialize_vmhd(data[acc:])
            minf.vmhd = vmhd
            acc += vmhd_size
        case "smhd":
            smdh, smdh_size := deserialize_smhd(data[acc:])
            minf.smhd = smdh
            acc += smdh_size
        case "hmhd":
            hmhd, hmhd_size := deserialize_hmhd(data[acc:])
            minf.hmhd = hmhd
            acc += hmhd_size
        case:
            nmhd, nmhd_size := deserialize_nmhd(data[acc:])
            minf.nmhd = nmhd
            acc += nmhd_size
    }

    dinf, dinf_size := deserialize_dinf(data[acc:])
    minf.dinf = dinf
    acc += dinf_size

    stbl, stbl_size := deserialize_stbl(data[acc:])
    minf.stbl = stbl
    acc += stbl_size

    return minf, acc
}
serialize_minf :: proc(minf: Minf) -> (data: []byte) {
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

    stbl_b := serialize_stbl(minf.stbl)
    data = slice.concatenate([][]byte{data[:], stbl_b[:]})
    return data
}



