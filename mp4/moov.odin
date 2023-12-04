package mp4

import "core:slice"
import "core:fmt"

// MovieBox
Moov :: struct { // moov
    box:            Box,
    mvhd: Mvhd,
    iods: Iods,
    traks:          [dynamic]Trak,
    udta: Udta,
    mvex: Mvex
}

deserialize_moov :: proc(data: []byte) -> (moov: Moov, acc: u64) {
    moov.traks =  make([dynamic]Trak, 0, 16)
    box, box_size := deserialize_box(data)
    moov.box = box
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
            case "mvhd":
                atom, atom_size := deserialize_mvhd(data[acc:])
                moov.mvhd = atom
                acc += atom_size
            case "iods":
                atom, atom_size := deserialize_iods(data[acc:])
                moov.iods = atom
                acc += atom_size
            case "trak":
                atom, atom_size := deserialize_trak(data[acc:])
                append(&moov.traks, atom)
                acc += atom_size
                case "udta":
                atom, atom_size := deserialize_udta(data[acc:])
                moov.udta = atom
                acc += atom_size
            case "mvex":
                atom, atom_size := deserialize_mvex(data[acc:])
                moov.mvex = atom
                acc += atom_size
            case:
                panic(fmt.tprintf("moov sub box '%v' not implemented", name))
        }
        if acc < size {
            sub_box, sub_box_size = deserialize_box(data[acc:])
            name = to_string(&sub_box.type)
        }
    }
    return moov, acc
}

serialize_moov :: proc(moov: Moov) -> (data: []byte) {
    box_b := serialize_box(moov.box)
    data = slice.concatenate([][]byte{[]byte{}, box_b[:]})
    name := moov.mvhd.fullbox.box.type
    if to_string(&name) == "mvhd" {
        bin := serialize_mvhd(moov.mvhd)
        data = slice.concatenate([][]byte{data[:], bin[:]})
    }

    name = moov.iods.fullbox.box.type
    if to_string(&name) == "iods" {
        bin := serialize_iods(moov.iods)
        data = slice.concatenate([][]byte{data[:], bin[:]})
    }
    
    if len(moov.traks) > 0 {
        for i:=0; i<len(moov.traks); i+=1 {
            bin := serialize_trak(moov.traks[i])
            data = slice.concatenate([][]byte{data[:], bin[:]})
        }
    }
    name = moov.udta.box.type
    if to_string(&name) == "udta" {
        bin := serialize_udta(moov.udta)
        data = slice.concatenate([][]byte{data[:], bin[:]})
    }
    name = moov.mvex.box.type
    if to_string(&name) == "mvex" {
        bin := serialize_mvex(moov.mvex)
        data = slice.concatenate([][]byte{data[:], bin[:]})
    }
    return data
}