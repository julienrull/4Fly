package mp4

// SegmentIndexBox
Sidx :: struct { // sidx
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

SegmentIndexBoxItems :: struct {
    reference_type:         byte, // 1 bit
    referenced_size:        u32be, // 31 bit
    subsegment_duration:    u32be,
    starts_with_SAP:        byte, // 1 bit
    SAP_type:               byte, // 3 bit
    SAP_delta_time:         u32be // 28 bit
}

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
    return Sidx{fullbox, reference_ID, timescale, earliest_presentation_time, earliest_presentation_time_extends, first_offset, first_offset_extends, reserved, reference_count, items}, acc
}