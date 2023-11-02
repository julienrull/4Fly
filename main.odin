package main

import "core:fmt"
import "core:os"
import "core:mem"
import "core:strings"
import "core:slice"
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

    mp4.dump(buffer, u64(len(buffer)))
    //mp4.print_mp4(buffer)
    // ftyp, ftyp_size := mp4.deserialize_ftype(buffer)
    // fmt.println(ftyp)
    // fmt.println(mp4.to_string(&ftyp.compatible_brands[0]), mp4.to_string(&ftyp.compatible_brands[1]))
    // fmt.println(mp4.deserialize_ftype(mp4.create_fragment_styp()))
}