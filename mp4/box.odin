package mp4


import "core:slice"

Box :: struct {
    size:       u32be,
    type:       u32be,
    largesize:  u64be, // if size == 1
    usertype:   [16]byte, // if type == uuid
}

serialize_box :: proc(box: Box) -> (data: []byte){
    size := box.size
    size_b := (^[4]byte)(&size)^
    type := box.type
    type_s := to_string(&type)
    type_b := (^[4]byte)(&type)^
    data = slice.concatenate([][]byte{size_b[:], type_b[:]})
    if size == 1 {
        largesize := box.largesize
        largesize_b := (^[8]byte)(&largesize)^
        data = slice.concatenate([][]byte{data, largesize_b[:]})
    }
    if type_s == "uuid" {
        usertype := box.usertype
        usertype_b := (^[16]byte)(&usertype)^
        data = slice.concatenate([][]byte{data, usertype_b[:]})
    }
    return data
}

deserialize_box :: proc(data: []byte) -> (Box, u64){
    acc: u64 = 0
    size := (^u32be)(&data[acc])^
    acc = acc + size_of(u32be)
    type := (^u32be)(&data[acc])^
    type_s := to_string(&type)
    acc = acc + size_of(u32be)
    largesize: u64be = 0
    usertype: [16]byte
    if size == 1 {
        largesize = (^u64be)(&data[acc])^
        acc = acc + size_of(u64be)
    }else if size == 0{
        // TODO: box extends to end of file
    }
    if type_s == "uuid" {
        usertype = (^[16]byte)(&data[acc])^
        acc = acc + size_of([16]byte)
    }
    return Box{size, type, largesize, usertype}, acc
}