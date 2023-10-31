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

FileTypeBox :: struct { // ftyp && styp
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
    box:            Box,
    movieHeaderBox: MovieHeaderBox,
    traks:          []TrackBox,
    udta: UserDataBox
}

UserDataBox :: struct{ // moov -> udta
    box:    Box,
    cprt:   CopyrightBox
}

CopyrightBox :: struct { // udta -> cprt
    fullBox: FullBox,
    pad: byte, // 1 bit
    language: [3]byte, // unsigned int(5)[3]
    notice: string
}

MovieHeaderBox :: struct {  // moov -> mvhd
    fullBox:                    FullBox,
    creation_time:              u32be,
    modification_time:          u32be,
    timescale:                  u32be,
    duration:                   u32be,
    creation_time_extends:      u64be,
    modification_time_extends:  u64be,
    duration_extends:           u64be,
    rate:                       i32be,
    volume:                     i16be,
    reserved:                   i16be,
    reserved2: [2]i32be,
    matrixx: [9]i32be,
    pre_defined: [6]i32be,
    next_track_ID: u32be,
}

deserialize_mvhd :: proc(data: []byte) -> MovieHeaderBox{
    mvhd := (^MovieHeaderBox)(&data[0])^
    return mvhd
}

TrackBox :: struct { // moov -> trak
    box:    Box,
    tkhd:   TrackHeaderBox,
    mdias:   []MediaBox,
    edtss:   []EditBox,
}


// TODO: props base on version : 0 or 1
TrackHeaderBox :: struct { // trak -> tkhd
    fullBox:                    FullBox,
    creation_time:              u32be,
    creation_time_extends:      u64be,
    modification_time:          u32be,
    modification_time_extends:  u64be,
    track_ID:                   u32be,
    reserved:                   u32be,
    duration:                   u32be,
    duration_extends:           u64be,

    reserved2:                  [2]u32be,
    layer:                      i16be,
    alternate_group:            i16be,
    volume:                     i16be,
    reserved3:                  u16be,
    matrixx:                    [9]i32be,
    width:                      u32be,
    height:                     u32be,
}



deserialize_tkhd  :: proc(data: []byte) -> TrackHeaderBox{
    track := (^TrackHeaderBox)(&data[0])^
    return track
}

EditBox :: struct { // trak -> edts
    box:    Box,
    elst:   EditListBox,
}

EditListBox :: struct { // edts -> elst
    fullBox:        FullBox,
    entry_count:    u32be,
    entries:        []EditListBoxEntries,
}

EditListBoxEntries :: struct {
    segment_duration:           u32be,
    media_time:                 i32be,
    segment_duration_extends:   u64be,
    media_time_extends:         i64be,

    media_rate_integer:         i16be,
    media_rate_fraction:        i16be,
}

MediaBox :: struct { // trak -> mdia
    box:    Box,
    mdhd:   MediaHeaderBox,
    hdlr:   HandlerBox,
}

MediaHeaderBox :: struct { // mdia -> mdhd
    fullBox:                    FullBox,
    creation_time:              u32be,
    creation_time_extends:      u64be,
    modification_time:          u32be,
    modification_time_extends:  u64be,
    timescale:                  u32be,
    duration:                   u32be,
    duration_extends:           u64be,

    pad:                    byte, // ! 1 bit 
    language:               [3]u8, // unsigned int(5)[3]
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



// Fragment --------------------------------------------------

Fragment :: struct {
    styp:   FileTypeBox,
    sidxs:   [dynamic]SegmentIndexBox,
    moof:   MovieFragmentBox,
    mdat:   MediaDataBox
}

deserialize_fragment :: proc(data: []byte) ->  (Fragment, u64) {
    acc: u64 = 0
    styp, styp_size := deserialize_ftype(data)
    acc += styp_size
    sidxs := make([dynamic]SegmentIndexBox, 0, 16)
    box, box_size := deserialize_box(data[acc:])
    name := to_string(&box.type)
    for name == "sidx" {
        sidx, sidx_size := deserialize_sidx(data[acc:])
        append(&sidxs, sidx)
        acc += sidx_size
        box, box_size = deserialize_box(data[acc:])
        name = to_string(&box.type)
    }
    moof, moof_size := deserialize_moof(data[acc:])
    acc += moof_size
    mdat, mdat_size := deserialize_mdat(data[acc:])
    acc += mdat_size
    return Fragment{
        styp,
        sidxs,
        moof,
        mdat
    }, acc
}

SegmentIndexBoxItems :: struct {
    reference_type:         byte, // 1 bit
    referenced_size:        u32be, // 31 bit
    subsegment_duration:    u32be,
    starts_with_SAP:        byte, // 1 bit
    SAP_type:               byte, // 3 bit
    SAP_delta_time:         u32be // 28 bit
}

SegmentIndexBox :: struct { // sidx
    fullBox:                                FullBox,
    reference_ID:                           u32be,
    timescale:                              u32be,
    earliest_presentation_time:             u32be,
    earliest_presentation_time_extends:     u64be,
    first_offset:                           u32be,
    first_offset_extends:                   u64be,
    reserved:                               u16be,
    reference_count:                        u16be,
    items:                                  []SegmentIndexBoxItems,
}

// TODO: implement deserialize_sidx
deserialize_sidx :: proc(data: []byte) ->  (SegmentIndexBox, u64) {
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
    items := make([]SegmentIndexBoxItems, reference_count)

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
    return SegmentIndexBox{fullbox, reference_ID, timescale, earliest_presentation_time, earliest_presentation_time_extends, first_offset, first_offset_extends, reserved, reference_count, items}, acc
}

MovieFragmentBox :: struct { // moof
    box:        Box,
    mfhd:       MovieFragmentHeaderBox,
    trafs:      [dynamic]TrackFragmentBox
}

deserialize_moof :: proc(data: []byte) -> (MovieFragmentBox, u64) { // TODO
    acc: u64 = 0
    size: u64 = 0
    box, box_size := deserialize_box(data)
    if box.size == 1 {
        size = u64(box.largesize)
    }else if box.size == 0{
        size = u64(len(data))
    }else {
        size = u64(box.size)
    }
    acc += box_size
    mfhd, mfhd_size := deserialize_mfhd(data[acc:])
    acc += mfhd_size
    trafs := make([dynamic]TrackFragmentBox, 0, 16)
    traf_box, traf_box_size := deserialize_box(data[acc:])
    name := to_string(&traf_box.type)
    for name == "traf" {
        fmt.println(name)
        traf, traf_size := deserialize_traf(data[acc:])
        append(&trafs, traf)
        acc += traf_size
        traf_box, traf_box_size = deserialize_box(data[acc:])
        name = to_string(&traf_box.type)
    }
    return MovieFragmentBox{box, mfhd, trafs}, acc
}

MovieFragmentHeaderBox :: struct { // moof -> mfhd
    fullbox:            FullBox,
    sequence_number:    u32be
}

deserialize_mfhd :: proc(data: []byte) -> (MovieFragmentHeaderBox, u64) { // TODO
    fullbox, fullbox_size := deserialize_fullbox(data)
    return MovieFragmentHeaderBox{fullbox, (^u32be)(&data[fullbox_size])^}, fullbox_size + size_of(u32be)
}

TrackFragmentBox :: struct { // moof -> traf
    box:    Box,
    tfhd:   TrackFragmentHeaderBox,
    trun:   TrackRunBox
}

deserialize_traf :: proc(data: []byte) -> (TrackFragmentBox, u64) {
    size: u64 = 0
    box, box_size := deserialize_box(data)
    if box.size == 1 {
        size = u64(box.largesize)
    }else if box.size == 0{
        size = u64(len(data))
    }else {
        size = u64(box.size)
    }
    tfhd, tfhd_size := deserialize_tfhd(data[box_size:])
    trun, trun_size := deserialize_trun(data[box_size + tfhd_size:])
    return TrackFragmentBox{
        box,
        tfhd,
        trun
    }, size
}

TrackFragmentHeaderBox :: struct { // traf -> tfhd
    fullbox:                    FullBox,
    track_ID:                   u32be,
    // all the following are optional fields
    base_data_offset:           u64be,
    sample_description_index:   u32be,
    default_sample_duration:    u32be,
    default_sample_size:        u32be,
    default_sample_flags:       u32be
}

deserialize_tfhd :: proc(data: []byte) -> (TrackFragmentHeaderBox, u64) { // TODO
    acc: u64 = 0
    size: u64 = 0
    fullbox, fullbox_size := deserialize_fullbox(data)
    if fullbox.box.size == 1 {
        size = u64(fullbox.box.largesize)
    }else {
        size = u64(fullbox.box.size)
    }
    acc += fullbox_size
    track_ID := (^u32be)(&data[acc])^
    acc += size_of(u32be)
    base_data_offset:           u64be
    sample_description_index:   u32be
    default_sample_duration:    u32be
    default_sample_size:        u32be
    default_sample_flags:       u32be
    if size >= acc + size_of(u64be) {
        base_data_offset = (^u64be)(&data[acc])^
        acc += size_of(u64be)
         if size >= acc + size_of(u32be) {
            sample_description_index = (^u32be)(&data[acc])^
            acc += size_of(u32be)
            if size >= acc + size_of(u32be) {
                default_sample_duration = (^u32be)(&data[acc])^
                acc += size_of(u32be)
                if size >= acc + size_of(u32be) {
                    default_sample_size = (^u32be)(&data[acc])^
                    acc += size_of(u32be)
                    if size >= acc + size_of(u32be) {
                        default_sample_flags = (^u32be)(&data[acc])^
                        acc += size_of(u32be)
                    }
                }
            }
         }
    }
    return TrackFragmentHeaderBox{
        fullbox,
        track_ID,
        base_data_offset,
        sample_description_index,
        default_sample_duration,
        default_sample_size,
        default_sample_flags
    }, acc
}

TrackRunBox :: struct { // traf -> trun
    fullbox:                FullBox,
    sample_count:           u32be,
    // the following are optional fields
    data_offset:            i32be,
    first_sample_flags:     u32be,
    // all fields in the following array are optional
    samples:                []TrackRunBoxSample
}

TrackRunBoxSample :: struct {
    sample_duration:                    u32be,
    sample_size:                        u32be,
    sample_flags:                       u32be,
    sample_composition_time_offset:     u32be,
}

deserialize_trun :: proc(data: []byte) -> (TrackRunBox, u64) { // TODO
    acc: u64 = 0
    size: u64 = 0
    fullbox, fullbox_size := deserialize_fullbox(data)
    if fullbox.box.size == 1 {
        size = u64(fullbox.box.largesize)
    }else {
        size = u64(fullbox.box.size)
    }
    acc += fullbox_size
    sample_count: u32be = (^u32be)(&data[acc])^
    acc = acc + size_of(u32be)
    data_offset:            i32be
    first_sample_flags:     u32be
    if size >= acc + size_of(u32be) {
        data_offset = (^i32be)(&data[acc])^
        acc = acc + size_of(u32be)
        if size >= acc + size_of(u32be) {
            first_sample_flags = (^u32be)(&data[acc])^
            acc = acc + size_of(u32be)
        }
    }
    samples := make([]TrackRunBoxSample, sample_count)
    for i:=0; i < int(sample_count); i+=1 {
        samples[i].sample_duration                    = (^u32be)(&data[acc])^
        acc = acc + size_of(u32be)
        samples[i].sample_size                        = (^u32be)(&data[acc])^
        acc = acc + size_of(u32be)
        samples[i].sample_flags                       = (^u32be)(&data[acc])^
        acc = acc + size_of(u32be)
        samples[i].sample_composition_time_offset     = (^u32be)(&data[acc])^
        acc = acc + size_of(u32be)
    }
    return TrackRunBox{
        fullbox,
        sample_count,
        data_offset,
        first_sample_flags,
        samples
    }, acc
}


MediaDataBox :: struct { // mdat
    box:    Box,
    //data:   []byte
}

deserialize_mdat :: proc(data: []byte) -> (MediaDataBox, u64) { // TODO
    acc: u64 = 0
    size: u64 = 0
    box, box_size := deserialize_box(data)
    if box.size == 1 {
        size = u64(box.largesize)
    }else if box.size == 0{
        size = u64(len(data))
    }else {
        size = u64(box.size)
    }
    acc += box_size
    //mdat_data := data[box_size:]
    acc += (size - box_size)

    return MediaDataBox{
        box,
        //mdat_data
    }, acc
}

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