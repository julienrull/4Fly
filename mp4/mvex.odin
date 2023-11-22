package mp4
import "core:mem"
import "core:slice"
import "core:fmt"


// Movie Extends Box
Mvex :: struct {
    box:    Box,
    mehd:   Mehd,
    trex:   Trex
}


deserialize_mvex :: proc(data: []byte) -> (mvex: Mvex, acc: u64) {
    box, box_size := deserialize_box(data)
    mvex.box = box
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
            case "mehd":
                atom, atom_size := deserialize_mehd(data[acc:])
                mvex.mehd = atom
                acc += atom_size
            case "trex":
                atom, atom_size := deserialize_trex(data[acc:])
                mvex.trex = atom
                acc += atom_size
            case:
                panic("mvex sub box not implemented")
        }
        if acc < size{
            sub_box, sub_box_size = deserialize_box(data[acc:])
            name := to_string(&sub_box.type)
        }
    }
    return mvex, acc
}

serialize_mvex :: proc(mvex: Mvex) -> (data: []byte){
    box_b := serialize_box(mvex.box)
    data = slice.concatenate([][]byte{[]byte{}, box_b[:]})
    name := mvex.mehd.fullbox.box.type
    if to_string(&name) == "mehd" {
        bin := serialize_mehd(mvex.mehd)
        data = slice.concatenate([][]byte{data[:], bin[:]})
    } 
    name = mvex.trex.fullbox.box.type
    if to_string(&name) == "trex" {
        bin := serialize_trex(mvex.trex)
        data = slice.concatenate([][]byte{data[:], bin[:]})
    }
    return data
}