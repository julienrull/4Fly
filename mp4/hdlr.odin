package mp4

// HandlerBox
Hdlr :: struct { // mdia or meta -> hdlr
    pre_defined: u32be,
    handler_type: u32be,
    reserved: [3]u32be,
    name: string
}
