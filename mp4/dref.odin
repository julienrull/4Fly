package mp4

import "core:slice"
import "core:fmt"

// DataReferenceBox

Dref :: struct {
    fullbox: FullBox,
    entry_count: u32be,
    data_entry_url: [dynamic]Url,
    data_entry_urn: [dynamic]Urn
}

// DataEntryUrlBox
Url :: struct {
    fullbox: FullBox,
    location: []byte // string
}

// DataEntryUrnBox
Urn :: struct {
    fullbox: FullBox,
    name: []byte, // string
    location: []byte // string
}

deserialize_dref :: proc(data: []byte) -> (dref: Dref, acc: u64) {
    fullbox, fullbox_size := deserialize_fullbox(data[acc:])
    dref.fullbox = fullbox
    acc += fullbox_size
    dref.entry_count = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    dref.data_entry_url = make([dynamic]Url, 0, dref.entry_count)
    dref.data_entry_urn = make([dynamic]Urn, 0, dref.entry_count)
    if dref.entry_count > 0 {
        for i:=0; i<int(dref.entry_count); i+=1 {
            sub_fullbox, sub_fullbox_size := deserialize_fullbox(data[acc:])
            sub_fullbox_type_s := to_string(&sub_fullbox.box.type)
            acc += sub_fullbox_size
            if sub_fullbox_type_s == "url"{
                if sub_fullbox.flags[2] != 1 {
                    char: rune = (^rune)(&data[acc])^
                    begin := acc
                    byte_count := 0
                    for char != 0 {
                        acc += size_of(rune)
                        char = (^rune)(&data[acc])^
                    }
                    acc += size_of(rune)
                    append(&dref.data_entry_url, Url{
                        sub_fullbox,
                        data[begin:acc]
                    })
                }
            }else if sub_fullbox_type_s == "urn" {
                if sub_fullbox.flags[2] != 1 {
                    char: rune = (^rune)(&data[acc])^
                    begin := acc
                    for char != 0 {
                        acc += size_of(rune)
                        char = (^rune)(&data[acc])^
                    }
                    acc += size_of(rune)
                    name := data[begin:acc]
                    begin = acc
                    for char != 0 {
                        acc += size_of(rune)
                        char = (^rune)(&data[acc])^
                    }
                    acc += size_of(rune)
                    location := data[begin:acc] 
                    append(&dref.data_entry_urn, Urn{
                        sub_fullbox,
                        name,
                        location,
                    })
                }
            }
        }
    }
    return dref, acc
}

serialize_dref :: proc(dref: Dref) -> (data: []byte) {
    fullbox_b := serialize_fullbox(dref.fullbox)
    entry_count := dref.entry_count
    entry_count_b := (^[4]byte)(&entry_count)^
    data = slice.concatenate([][]byte{fullbox_b[:], entry_count_b[:]})
    for i:=0; i<len(dref.data_entry_url); i+=1 {
        sub_fullbox_b := serialize_fullbox(dref.data_entry_url[i].fullbox)
        data = slice.concatenate([][]byte{data[:], sub_fullbox_b[:]})
        data = slice.concatenate([][]byte{data[:], dref.data_entry_url[i].location[:]})
    }
    for i:=0; i<len(dref.data_entry_urn); i+=1 {
        sub_fullbox_b := serialize_fullbox(dref.data_entry_urn[i].fullbox)
        data = slice.concatenate([][]byte{data[:], sub_fullbox_b[:]})
        data = slice.concatenate([][]byte{data[:], dref.data_entry_urn[i].name[:]})
        data = slice.concatenate([][]byte{data[:], dref.data_entry_urn[i].location[:]})
    }
    return data
}