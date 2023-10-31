package main

import "core:fmt"
import "core:os"
import "core:mem"
import "core:strings"
import json "core:encoding/json"
import "mp4"


main :: proc() {
    args := os.args[1:]
    size := os.file_size_from_path(args[0])
    f, ferr := os.open(args[0])
    if ferr != 0 {
            return
    }
    defer os.close(f)
    buffer, err := mem.alloc_bytes((int)(size))
    defer delete(buffer)
    os.read(f, buffer)

    mp4.print_mp4(buffer)
    // fragment, fragment_size := mp4.deserialize_fragment(buffer)
    // data, err_parse := json.marshal(fragment)
    // fmt.printf("%s", data)

    
    // acc: u64 = 0
    // styp, styp_size := mp4.deserialize_ftype(buffer)
    // acc = acc + u64(styp.box.size)
    // sidx, sidx_size := mp4.deserialize_sidx(buffer[acc:])
    // fmt.println(sidx)
    // fmt.println(sidx_size)
}