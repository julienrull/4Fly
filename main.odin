package main

import "core:fmt"
import "core:os"
import "core:mem"
import "core:strings"
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
    // ftyp := mp4.deserialize_ftype(buffer)
    // fmt.println(ftyp)
    // offset := int(ftyp.box.size + size_of(mp4.Box))
    // mvhd := mp4.deserialize_mvhd(buffer[offset:])
    // fmt.println(mvhd)
    // offset = offset + int(mvhd.fullBox.box.size)
    // box := mp4.deserialize_box(buffer[offset:])
    // mp4.print_box(box)
    // offset = offset + size_of(mp4.Box)
    // track := mp4.deserialize_tkhd(buffer[offset:])
    // fmt.println(track)
    // offset = offset + int(track.fullBox.box.size)
    // edts := mp4.deserialize_box(buffer[offset:])
    // mp4.print_box(edts)
    // offset = offset + int(edts.size)
    // mdia := mp4.deserialize_box(buffer[offset:])
    // mp4.print_box(mdia)


}