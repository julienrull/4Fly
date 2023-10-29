package mp4
import "core:fmt"
import "core:strings"
import "core:slice"
import "core:mem"

BOX_SIZE :: size_of(u32be) *2

Box :: struct {
    size: u32be,
    type: u32be,
}

FullBox :: struct {
    box:        Box,
    version:    u8,
    flags:      [3]byte,
}

print_box :: proc(box: Box){
    type := box.type
    type_b := (^byte)(&type)
    fmt.println("Type:", strings.string_from_ptr(type_b, size_of(u32be)))
    fmt.println("Size:", box.size)
}

deserialize_box :: proc(data: []byte) -> Box{
    return (^Box)(&data[0])^
}


FileTypeBox :: struct { // ftyp
    box:          Box,
    major_brand:        u32be,
    minor_version:      u32be,
    compatible_brands:  [dynamic]u32be,
}


deserialize_ftype :: proc(data: []byte) -> FileTypeBox{
    box := deserialize_box(data)
    know_size := size_of(Box) + size_of(u32be)*2
    remain_size := (int)(box.size) - know_size
    ftyp_b := data[size_of(Box):]
    compatible_brands_b := data[size_of(Box) + size_of(u32be)*2:]
    compatible_brands := make([dynamic]u32be, 0, remain_size / size_of(u32be))
    i := 0
    for i < remain_size / size_of(u32be) {
        brand := (^u32be)(&compatible_brands_b[i*4])^
        append(&compatible_brands, brand)
        i=i+1
    }
    return FileTypeBox{
        box,
        (^u32be)(&ftyp_b[0])^,
        (^u32be)(&ftyp_b[size_of(u32be)])^,
        compatible_brands
    }
}

MovieBox :: struct { // moov
    box: Box,
    movieHeaderBox: MovieHeaderBox
}

MovieHeaderBox :: struct {  // moov -> mvhd
    fullBox:                FullBox,
    creation_time:          u32be,
    modification_time:      u32be,
    timescale:              u32be,
    duration:               u32be,
    rate:                   i32be,
    volume:                 i16be
}

deserialize_mvhd :: proc(data: []byte) -> MovieHeaderBox{
    mvhd := (^MovieHeaderBox)(&data[0])^
    return mvhd
}

TrackBox :: struct { // moov -> trak
    box:                Box,
    trackHeaderBox:     TrackHeaderBox
}


// TODO: props base on version : 0 or 1
TrackHeaderBox :: struct { // trak -> tkhd
    fullBox:                FullBox,
    creation_time:          u32be,
    modification_time:      u32be,
    track_ID:               u32be,
    reserved:               u32be,
    duration:               u32be,
    reserved2:              [2]u32be,
    layer:                  i16be,
    alternate_group:        i16be,
    volume:                 i16be,
    reserved3:              u16be,
    matrixx:                [9]i32be,
    width:                  u32be,
    height:                 u32be,
}



deserialize_tkhd  :: proc(data: []byte) -> TrackHeaderBox{
    track := (^TrackHeaderBox)(&data[0])^
    return track
}

TrackReferenceBox :: struct { // trak -> tref
    box:    Box,
}

TrackReferenceTypeBox :: struct { // trak -> hint or cdsc
    box:    Box,
    track_IDs: []u32be
}

MediaBox :: struct { // trak -> mdia
    box:    Box,
}

// TODO: props base on version : 0 or 1
MediaHeaderBox :: struct { // mdia -> mdhd
    fullBox:                FullBox,
    creation_time:          u32be,
    modification_time:      u32be,
    timescale:              u32be,
    duration:               u32be,
    pad:                    byte, // ! 1 bit 
    language:               [3][5]u8, // unsigned int(5)[3]
    pre_defined:            u16be
}

HandlerBox :: struct { // mdia or meta -> hdlr
    pre_defined: u32be,
    handler_type: u32be,
    reserved: [3]u32be,
    name: string
}

MediaInformationBox :: struct { // mdia -> minf
    box:    Box,
}

VideoMediaHeaderBox :: struct { // minf -> vmhd
    fullBox:        FullBox,
    graphicsmode:   u16be, // copy, see below
    opcolor:        [3]u16be,
}

SoundMediaHeaderBox :: struct { // minf -> smhd
    fullBox:    FullBox,
    balance:    i16be,
    reserved:   u16be
}

HintMediaHeaderBox :: struct { // minf -> hmhd
    fullBox:    FullBox,
    maxPDUsize: u16be,
    avgPDUsize: u16be,
    maxbitrate: u32be,
    avgbitrate: u32be,
    reserved:   u32be
}

NullMediaHeaderBox :: struct { // minf -> nmhd
    fullBox:    FullBox,
}

// Page 19 TABLE
// page 31 RESUM

to_string :: proc(value: ^u32be) -> string {
    
    value_b := (^byte)(value)
    str := strings.string_from_ptr(value_b, size_of(u32be))
    return str
}



// print_mp4 :: proc(data: []byte) {
//     offset: u64 = 0
//     size := u64(len(data))
//     last_box_size: u64 = 0
//     level: u64 = 0
//     for offset < size {
//         sub_data := data[offset:]
//         box := deserialize_box(sub_data)
//         if slice.contains(BOXES, to_string(&box.type)) {
//             level = level + 1
//             fmt.println(to_string(&box.type), level)
//             offset = offset + size_of(Box)
//             last_box_size = u64(box.size);
//         }else{
//             offset = offset + last_box_size - size_of(Box)
//             level = level - 1
//         }
//     }
// }

print_mp4_level :: proc(name: string, level: int){
    str := ""
    err: mem.Allocator_Error
    i := 0
    for i < level {
        a := [?]string { str, "-"}
        str, err = strings.concatenate(a[:])
        i=i+1
    }
    a := [?]string { str, name}
    str, err = strings.concatenate(a[:])
    fmt.println(str, level)
}

print_mp4 :: proc(data: []byte) {
    offset: u64 = 0
    size := u64(len(data))
    last_box_size: u64 = 0
    last_level: int = 0
    found := false
    for offset < size {
        sub_data := data[offset:]
        box := deserialize_box(sub_data)
        name := to_string(&box.type)
        level, ok := BOXES[name]
        if ok {
            lvl := level
            if level == 10 {
                if !found {
                    lvl = last_level
                }else{
                    lvl = last_level + 1
                }
            }
            print_mp4_level(name, lvl)
            offset = offset + size_of(Box)
            last_box_size = u64(box.size);
            last_level = lvl
            found = true
        }else{
            found = false
            offset = offset + last_box_size - size_of(Box)
        }
    }
}