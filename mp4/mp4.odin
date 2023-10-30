package mp4
import "core:fmt"
import "core:strings"
import "core:slice"
import "core:mem"

BOX_SIZE :: size_of(u32be) *2

// Box :: struct {
//     size: u32be,
//     type: u32be,
// }
to_string :: proc(value: ^u32be) -> string {
    value_b := (^byte)(value)
    str := strings.string_from_ptr(value_b, size_of(u32be))
    return str
}


Box :: struct {
    size: u32be,
    type: u32be,
    largesize: u64be, // if size == 1
    usertype: [16]byte, // if type == uuid
}

deserialize_box :: proc(data: []byte) -> (Box, u64){
    acc: u64 = 0
    size := (^u32be)(&data[acc])^
    acc = acc + size_of(u32be)
    type := (^u32be)(&data[acc])^
    type_s := to_string(&type)
    acc = acc + size_of(u32be)
    largesize: u64be = 0
    usertype: [16]byte
    if size == 1 {
        largesize = (^u64be)(&data[acc])^
        acc = acc + size_of(u64be)
    }else if size == 0{
        // TODO: box extends to end of file
    }
    if type_s == "uuid" {
        usertype = (^[16]byte)(&data[acc])^
        acc = acc + size_of([16]byte)
    }
    return Box{size, type, largesize, usertype}, acc
}


// deserialize_box :: proc(data: []byte) -> Box{
//     return (^Box)(&data[0])^
// }


FullBox :: struct {
    box:        Box,
    version:    u8,
    flags:      [3]byte,
}

deserialize_fullbox :: proc(data: []byte) ->( FullBox, u64) {
    acc: u64 = 0
    box, box_size := deserialize_box(data)
    acc = acc + box_size
    version := (^u8)(&data[acc])^
    acc = acc + size_of(u8)
    flags := (^[3]byte)(&data[acc])^
    acc = acc + size_of([3]byte)
    return FullBox{box, version, flags}, acc
}

print_box :: proc(box: Box){
    type := box.type
    type_b := (^byte)(&type)
    fmt.println("Type:", strings.string_from_ptr(type_b, size_of(u32be)))
    fmt.println("Size:", box.size)
}

FileTypeBox :: struct { // ftyp
    box:          Box,
    major_brand:        u32be,
    minor_version:      u32be,
    compatible_brands:  [dynamic]u32be,
}


deserialize_ftype :: proc(data: []byte) -> (FileTypeBox, u64) {
    acc: u64 = 0
    box, box_size := deserialize_box(data)
    acc = acc + box_size
    major_brand := (^u32be)(&data[acc])^
    acc = acc + size_of(u32be)
    minor_version := (^u32be)(&data[acc])^
    acc = acc + size_of(u32be)
    know_size := box_size + size_of(u32be)*2
    remain_size: u64 = 0
    if box.size == 1 {
        remain_size = (u64)(box.largesize) - know_size
    }else{
        remain_size = (u64)(box.size) - know_size
    }
    compatible_brands_b := data[acc:]
    compatible_brands := make([dynamic]u32be, 0, remain_size / size_of(u32be))
    i:u64 = 0
    for i < remain_size / u64(size_of(u32be)) {
        brand := (^u32be)(&compatible_brands_b[i*4])^
        append(&compatible_brands, brand)
        i=i+1
    }
    acc = acc + remain_size
    return FileTypeBox{ box, major_brand, minor_version, compatible_brands }, acc
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

SidxItems :: struct {
    reference_type: byte, // 1 bit
    referenced_size: u32be, // 31 bit
    subsegment_duration: u32be,
    starts_with_SAP: byte, // 1 bit
    SAP_type: byte, // 3 bit
    SAP_delta_time: u32be // 28 bit
}

Sidx :: struct {
    fullBox:    FullBox,
    reference_ID: u32be,
    timescale: u32be,
    earliest_presentation_time: u32be,
    earliest_presentation_time_extends: u64be,
    first_offset: u32be,
    first_offset_extends: u64be,
    reserved: u16be,
    reference_count: u16be,
    items:  []SidxItems,
}

// TODO: implement deserialize_sidx
deserialize_sidx :: proc(data: []byte) ->  (Sidx, u64) {
    acc: u64 = 0
    fullbox, fullbox_size := deserialize_fullbox(data)
    acc = acc + fullbox_size
    reference_ID := (^u32be)(&data[acc])^
    acc = acc + size_of(u32be)
    timescale := (^u32be)(&data[acc])^
    acc = acc + size_of(u32be)
    earliest_presentation_time: u32be
    first_offset: u32be
    earliest_presentation_time_extends: u64be
    first_offset_extends: u64be
    if fullbox.version == 1 {
        earliest_presentation_time_extends = (^u64be)(&data[acc])^
        acc = acc + size_of(u64be)
        first_offset_extends = (^u64be)(&data[acc])^
        acc = acc + size_of(u64be)
    }else {
        earliest_presentation_time = (^u32be)(&data[acc])^
        acc = acc + size_of(u32be)
        first_offset = (^u32be)(&data[acc])^
        acc = acc + size_of(u32be)
    }
    reserved := (^u16be)(&data[acc])^
    acc = acc + size_of(u16be)
    reference_count := (^u16be)(&data[acc])^
    acc = acc + size_of(u16be)
    items := make([]SidxItems, reference_count)

    for i:=0; i < int(reference_count); i+=1 {
        tmp: u32be = (^u32be)(&data[acc])^
        items[i].reference_type = (byte)((tmp & 0x80000000)>>24)
        items[i].referenced_size = tmp & 0x7fffffff
        acc = acc + size_of(u32be)
        items[i].subsegment_duration = (^u32be)(&data[acc])^
        acc = acc + size_of(u32be)
        tmp = (^u32be)(&data[acc])^
        items[i].starts_with_SAP = (byte)((tmp & 0x80000000)>>24)
        items[i].SAP_type = (byte)((tmp & 0x70000000)>>24)
        items[i].SAP_delta_time = tmp & 0xfffffff
        acc = acc + size_of(u32be)
    }
    return Sidx{fullbox, reference_ID, timescale, earliest_presentation_time, earliest_presentation_time_extends, first_offset, first_offset_extends, reserved, reference_count, items}, acc
}

// deserialize_sidx :: proc(data: []byte) ->  Sidx{
//     sidx := (^Sidx)(&data[0])^
//     return sidx
// }

// Page 19 TABLE
// page 31 RESUM



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
    previous_box_size: u64 =  0
    not_found_count := 0
    for offset < size {
        if not_found_count > 4 {
            panic("Too many unreadable boxes !")
        }
        sub_data := data[offset:]
        box, box_size := deserialize_box(sub_data)
        name := to_string(&box.type)
        level, ok := BOXES[name]
        // if box.size == 0 {
        //     fmt.println("box.size == 0")
        //     fmt.println(name)
        //     panic("PANIC")
        // }
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
            if box.size == 1 {
                last_box_size = u64(box.largesize)
            }else if box.size == 0{
                fmt.println("box.size == 0")
                last_box_size = size - offset
            }else{
                last_box_size = u64(box.size)
            }
            offset = offset + box_size
            previous_box_size = box_size
            last_level = lvl
            found = true
            not_found_count = 0
        }else{
            //fmt.println("unreadable", name)
            not_found_count = not_found_count + 1
            found = false
            offset = offset + last_box_size - previous_box_size
        }
    }
    fmt.println("EXIT")
}