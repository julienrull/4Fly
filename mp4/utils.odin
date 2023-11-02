package mp4

import "core:fmt"
import "core:strings"
import "core:mem"


to_string :: proc(value: ^u32be) -> string {
    value_b := (^byte)(value)
    str := strings.string_from_ptr(value_b, size_of(u32be))
    return str
}

print_box :: proc(box: Box){
    type := box.type
    type_b := (^byte)(&type)
    fmt.println("Type:", strings.string_from_ptr(type_b, size_of(u32be)))
    fmt.println("Size:", box.size)
}

print_mp4_level :: proc(name: string, level: int){
    str := ""
    err: mem.Allocator_Error
    i := 0
    for i < level - 1 {
        a := [?]string { str, "-"}
        str, err = strings.concatenate(a[:])
        i=i+1
    }
    a := [?]string { str, name}
    str, err = strings.concatenate(a[:])
    fmt.println(str, level)
}

dump :: proc(data: []byte, size: u64, level: int = 0) -> (offset: u64) { 
    lvl := level + 1
    for offset < size {
        box, box_size := deserialize_box(data[offset:])
        type_s := to_string(&box.type)
        _, ok := BOXES[type_s]
        if ok {
            print_mp4_level(type_s, lvl)
            offset += dump(data[offset + box_size:], u64(box.size) - box_size, lvl) + box_size
        }else{
            offset = size
        }
    }
    return offset
}