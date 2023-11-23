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
    size: u64
    if box.size == 1 {
        size = u64(box.largesize)
    }else if box.size == 0 {
        size = u64(len(data))
    }else {
        size =  u64(box.size)
    }
    name := to_string(&sub_box.type)
    for  acc < size {
        switch name {
            case "vmhd":
                atom, atom_size := deserialize_vmhd(data[acc:])
                minf.vmhd = atom
                acc += atom_size
                // fmt.println("name", name)
                // fmt.println("atom.size", atom.fullbox.box.size)
                // fmt.println("atom_size", atom_size)
            case "smhd":
                atom, atom_size := deserialize_smhd(data[acc:])
                minf.smhd = atom
                acc += atom_size
                // fmt.println("name", name)
                // fmt.println("atom.size", atom.fullbox.box.size)
                // fmt.println("atom_size", atom_size)
            case "hmhd":
                atom, atom_size := deserialize_hmhd(data[acc:])
                minf.hmhd = atom
                acc += atom_size
                // fmt.println("name", name)
                // fmt.println("atom.size", atom.fullbox.box.size)
                // fmt.println("atom_size", atom_size)
            case "nmhd":
                atom, atom_size := deserialize_nmhd(data[acc:])
                minf.nmhd = atom
                acc += atom_size
                // fmt.println("name", name)
                // fmt.println("atom.size", atom.fullbox.box.size)
                // fmt.println("atom_size", atom_size)
            case "dinf":
                atom, atom_size := deserialize_dinf(data[acc:])
                minf.dinf = atom
                acc += atom_size
                // fmt.println("name", name)
                // fmt.println("atom.size", atom.box.size)
                // fmt.println("atom_size", atom_size)
            case "stbl":
                atom, atom_size := deserialize_stbl(data[acc:], handle_type)
                minf.stbl = atom
                acc += atom_size
                // fmt.println("name", name)
                // fmt.println("atom.size", atom.box.size)
                // fmt.println("atom_size", atom_size)
            case:
                panic(fmt.tprintf("minf sub box '%v' not implemented", name))
        }
        if acc < size {
            sub_box, sub_box_size = deserialize_box(data[acc:])
            name = to_string(&sub_box.type)
        }
    }
    return minf, acc
}

serialize_minf :: proc(minf: Minf, handle_type: u32be) -> (data: []byte) {
    box_b := serialize_box(minf.box)
    type := minf.vmhd.fullbox.box.type
    name := to_string(&type)
    if name == "vmhd" {
        vmhd_b := serialize_vmhd(minf.vmhd)    
        data = slice.concatenate([][]byte{box_b[:], vmhd_b[:]})
    }
    type = minf.smhd.fullbox.box.type
    name = to_string(&type)
    if name == "smhd" {
        smhd_b := serialize_smhd(minf.smhd)    
        data = slice.concatenate([][]byte{box_b[:], smhd_b[:]})
    }
    type = minf.hmhd.fullbox.box.type
    name = to_string(&type)
    if name == "hmhd" {
        hmhd_b := serialize_hmhd(minf.hmhd)    
        data = slice.concatenate([][]byte{box_b[:], hmhd_b[:]})
    }
    type = minf.nmhd.fullbox.box.type
    name = to_string(&type)
    if name == "nmhd" {
        nmhd_b := serialize_nmhd(minf.nmhd)    
        data = slice.concatenate([][]byte{box_b[:], nmhd_b[:]})
    }
    dinf_b := serialize_dinf(minf.dinf)
    data = slice.concatenate([][]byte{data[:], dinf_b[:]})
    stbl_b := serialize_stbl(minf.stbl, handle_type)
    data = slice.concatenate([][]byte{data[:], stbl_b[:]})
    return data
}



