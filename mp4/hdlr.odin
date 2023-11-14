package mp4

import "core:slice"

// HandlerBox
Hdlr :: struct { // mdia or meta -> hdlr
    pre_defined: u32be,
    handler_type: u32be,
    reserved: [3]u32be,
    name: []byte
}
