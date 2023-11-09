package mp4

import "core:slice"

// SampleTableBox
Stbl :: struct { // minf -> stbl
    box:    Box,
    stts:   Stts,
    ctts:   Ctts,
    stsd:   Stsd,
    stsz:   Stsz,
    stz2:   Stz2,
    stsc:   Stsc,
    stco:   Stco,
    co64:   Co64,
    stss:   Stss,
    stsh:   Stsh,
    stdp:   Stdp,
    padb:   Padb
    // sgpd: Sgpd
    // sbgp: Sbgp
}

deserialize_stbl :: proc(data: []byte) -> (stbl: Stbl, acc: u64) {
    box, box_size := deserialize_box(data)
    stbl.box = box
    acc += box_size
    sub_box, sub_box_size := deserialize_box(data[acc:])
    name := to_string(&sub_box.type)
    for  acc < u64(box.size) {
        switch name {
            case "stts":
                atom, atom_size := deserialize_stts(data[acc:])
                stbl.stts = atom
                acc += atom_size
            case "ctts":
                atom, atom_size := deserialize_ctts(data[acc:])
                stbl.ctts = atom
                acc += atom_size
            case "stsd":
                atom, atom_size := deserialize_stsd(data[acc:], "") // TODO
                stbl.stsd = atom
                acc += atom_size
            case "stsz":
                atom, atom_size := deserialize_stsz(data[acc:])
                stbl.stsz = atom
                acc += atom_size
            case "stz2":
                atom, atom_size := deserialize_stz2(data[acc:])
                stbl.stz2 = atom
                acc += atom_size
            case "stsc":
                atom, atom_size := deserialize_stsc(data[acc:])
                stbl.stsc = atom
                acc += atom_size
            case "stco":
                atom, atom_size := deserialize_stco(data[acc:])
                stbl.stco = atom
                acc += atom_size
            case "co64":
                atom, atom_size := deserialize_co64(data[acc:])
                stbl.co64 = atom
                acc += atom_size
            case "stss":
                atom, atom_size := deserialize_stss(data[acc:])
                stbl.stss = atom
                acc += atom_size
            case "stsh":
                atom, atom_size := deserialize_stsh(data[acc:])
                stbl.stsh = atom
                acc += atom_size
            case "stdp":
                atom, atom_size := deserialize_stdp(data[acc:], 0) // TODO
                stbl.stdp = atom
                acc += atom_size
            case "padb":
                atom, atom_size := deserialize_padb(data[acc:])
                stbl.padb = atom
                acc += atom_size
            // case "sgpd":
                    // atom, atom_size := deserialize_sgpd(data[acc:])
                    // stbl.sgpd = atom
                    // acc += atom_size
            // case "sbgp":
                    // atom, atom_size := deserialize_sbgp(data[acc:])
                    // stbl.sbgp = atom
                    // acc += atom_size
            case:
                panic("stbl sub box not implemented")
        }
        sub_box, sub_box_size = deserialize_box(data[acc:])
        name := to_string(&sub_box.type)
    }
    return stbl, acc
}

serialize_stbl :: proc(stbl: Stbl) -> (data: []byte) {
    box_b := serialize_box(stbl.box)
    data = slice.concatenate([][]byte{[]byte{}, box_b[:]})
    name := stbl.stts.fullbox.box.type
    if to_string(&name) == "stts" {
        bin := serialize_stts(stbl.stts)
        data = slice.concatenate([][]byte{data[:], bin[:]})
    }
    name = stbl.ctts.fullbox.box.type
    if to_string(&name) == "ctts" {
        bin := serialize_ctts(stbl.ctts)
        data = slice.concatenate([][]byte{data[:], bin[:]})
    }
    name = stbl.stsd.fullbox.box.type
    if to_string(&name) == "stsd" {
        bin := serialize_stsd(stbl.stsd, "") // TODO
        data = slice.concatenate([][]byte{data[:], bin[:]})
    }
    name = stbl.stsz.fullbox.box.type
    if to_string(&name) == "stsz" {
        bin := serialize_stsz(stbl.stsz)
        data = slice.concatenate([][]byte{data[:], bin[:]})
    }
    name = stbl.stz2.fullbox.box.type
    if to_string(&name) == "stz2" {
        bin := serialize_stz2(stbl.stz2)
        data = slice.concatenate([][]byte{data[:], bin[:]})
    }
    name = stbl.stsc.fullbox.box.type
    if to_string(&name) == "stsc" {
        bin := serialize_stsc(stbl.stsc)
        data = slice.concatenate([][]byte{data[:], bin[:]})
    }
    name = stbl.stco.fullbox.box.type
    if to_string(&name) == "stco" {
        bin := serialize_stco(stbl.stco)
        data = slice.concatenate([][]byte{data[:], bin[:]})
    }
    name = stbl.co64.fullbox.box.type
    if to_string(&name) == "co64" {
        bin := serialize_co64(stbl.co64)
        data = slice.concatenate([][]byte{data[:], bin[:]})
    }
    name = stbl.stss.fullbox.box.type
    if to_string(&name) == "stss" {
        bin := serialize_stss(stbl.stss)
        data = slice.concatenate([][]byte{data[:], bin[:]})
    }
    name = stbl.stsh.fullbox.box.type
    if to_string(&name) == "stsh" {
        bin := serialize_stsh(stbl.stsh)
        data = slice.concatenate([][]byte{data[:], bin[:]})
    }
    name = stbl.stdp.fullbox.box.type
    if to_string(&name) == "stdp" {
        bin := serialize_stdp(stbl.stdp, 0) // TODO
        data = slice.concatenate([][]byte{data[:], bin[:]})
    }
    name = stbl.padb.fullbox.box.type
    if to_string(&name) == "padb" {
        bin := serialize_padb(stbl.padb)
        data = slice.concatenate([][]byte{data[:], bin[:]})
    }
    // name = stbl.sgpd.fullbox.box.type
    // if to_string(&name) == "sgpd" {
    //     bin := serialize_sgpd(stbl.sgpd)
    //     data = slice.concatenate([][]byte{data[:], bin[:]})
    // }
    // name = stbl.sbgp.fullbox.box.type
    // if to_string(&name) == "sbgp" {
    //     bin := serialize_sbgp(stbl.sbgp)
    //     data = slice.concatenate([][]byte{data[:], bin[:]})
    // }

    return data
}