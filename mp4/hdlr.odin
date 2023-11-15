package mp4

import "core:slice"

// HandlerBox
Hdlr :: struct { // mdia or meta -> hdlr
    fullbox:        FullBox,
    pre_defined:    u32be,
    handler_type:   u32be,
    reserved:       [3]u32be,
    name:           []byte // string
}

deserialize_hdlr :: proc(data: []byte) -> (hdlr: Hdlr, acc: u64) {
    fullbox, fullbox_size := deserialize_fullbox(data[acc:])
    hdlr.fullbox = fullbox
    acc += fullbox_size

    hdlr.pre_defined = (^u32be)(&data[acc])^
    acc += size_of(u32be)

    hdlr.handler_type = (^u32be)(&data[acc])^
    acc += size_of(u32be)

    hdlr.reserved = (^[3]u32be)(&data[acc])^
    acc += size_of([3]u32be)

    remain := u64(fullbox.box.size) - acc 

    hdlr.name = data[acc:acc + remain]

    return hdlr, acc
}

serialize_hdlr :: proc(hdlr: Hdlr) -> (data: []byte) {

    fullbox_b := serialize_fullbox(hdlr.fullbox)
    pre_defined := hdlr.pre_defined
    pre_defined_b := (^[4]byte)(&pre_defined)^
    data = slice.concatenate([][]byte{fullbox_b[:], pre_defined_b[:]})

    handler_type := hdlr.handler_type
    handler_type_b := (^[4]byte)(&handler_type)^
    data = slice.concatenate([][]byte{data[:], handler_type_b[:]})

    reserved := hdlr.reserved
    reserved_b := (^[4]byte)(&reserved)^
    data = slice.concatenate([][]byte{data[:], reserved_b[:]})

    data = slice.concatenate([][]byte{fullbox_b[:], hdlr.name[:]})

    return data
}