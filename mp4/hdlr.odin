package mp4

import "core:slice"
import "core:strings"
import "core:os"
import "core:log"

// HandlerBox
Hdlr :: struct { // mdia or meta -> hdlr
    fullbox:        FullBox,
    pre_defined:    u32be,
    handler_type:   u32be,
    reserved:       [3]u32be,
    name:           []byte // string
}


HdlrV2 :: struct { // mdia or meta -> hdlr
    box:            BoxV2,
    //pre_defined:    u32be,
    handler_type:   string,
    //reserved:       [3]u32be,
    name:           string // string
}

read_hdlr :: proc(handle: os.Handle, id: int = 1) -> (atom: HdlrV2, err: FileError) {
    buffer := [4]u8{}
    atom.box = select_box(handle, "hdlr", id) or_return
    total_read := int(atom.box.header_size)
    total_seek := fseek(handle, i64(atom.box.header_size) + 4, os.SEEK_CUR) or_return
    total_read += fread(handle, buffer[:]) or_return
    atom.handler_type =  strings.clone_from_bytes(buffer[:])
    total_seek += fseek(handle, 12, os.SEEK_CUR) or_return
    remain := atom.box.total_size - (atom.box.header_size + 20)
    name_buffer := make([]u8, remain)
    defer delete(name_buffer)
    total_read += fread(handle, name_buffer[:]) or_return
    atom.name =  strings.clone_from_bytes(name_buffer[:])
    return atom, nil
}

deserialize_hdlr :: proc(data: []byte) -> (hdlr: Hdlr, acc: u64) {
    fullbox, fullbox_size := deserialize_fullbox(data[acc:])
    hdlr.fullbox = fullbox
    size: u64
    if fullbox.box.size == 1 {
        size = u64(fullbox.box.largesize)
    }else if fullbox.box.size == 0 {
        size = u64(len(data))
    }else {
        size = u64(fullbox.box.size)
    }
    acc += fullbox_size

    hdlr.pre_defined = (^u32be)(&data[acc])^
    acc += size_of(u32be)

    hdlr.handler_type = (^u32be)(&data[acc])^
    acc += size_of(u32be)

    hdlr.reserved = (^[3]u32be)(&data[acc])^
    acc += size_of([3]u32be)

    remain := size - acc

    hdlr.name = data[acc:acc + remain]
    acc += remain

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
    reserved_b := (^[12]byte)(&reserved)^
    data = slice.concatenate([][]byte{data[:], reserved_b[:]})

    data = slice.concatenate([][]byte{data[:], hdlr.name[:]})

    return data
}
