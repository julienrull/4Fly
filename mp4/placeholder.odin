
package mp4

import "core:slice"
import "core:fmt"

Placeholder :: struct{
    box:    Box,
    content:   []byte
}

deserialize_placeholder :: proc(data: []byte) -> (placeholder: Placeholder, acc: u64) {
    box, box_size :=  deserialize_box(data[acc:])
    acc += box_size
    placeholder.box = box
    size: u64 = 0
    if box.size == 1 {
        size = u64(box.largesize)
    }else if box.size == 0 {
        size = u64(len(data))
    }else {
        size = u64(box.size)
    }
    remain := (size - acc)
    placeholder.content = data[acc:acc+remain]
    acc += remain
    return placeholder, acc
}

serialize_placeholder :: proc(placeholder: Placeholder) -> (data: []byte) {
    box_b := serialize_box(placeholder.box)
    data = slice.concatenate([][]byte{box_b[:], placeholder.content[:]})
    return data
}
