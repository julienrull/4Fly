package mp4

import "core:mem"
import "core:slice"

// SegmentIndexBox
Sidx :: struct { // sidx
    fullbox:                                FullBox,
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

deserialize_sidx :: proc(data: []byte) ->  (sidx: Sidx, acc: u64) {
    fullbox, fullbox_size := deserialize_fullbox(data)
    sidx.fullbox = fullbox
    acc += fullbox_size
    sidx.reference_ID = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    sidx.timescale = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    if fullbox.version == 1 {
        sidx.earliest_presentation_time_extends = (^u64be)(&data[acc])^
        acc += size_of(u64be)
        sidx.first_offset_extends = (^u64be)(&data[acc])^
        acc += size_of(u64be)
    }else {
        sidx.earliest_presentation_time = (^u32be)(&data[acc])^
        acc += size_of(u32be)
        sidx.first_offset = (^u32be)(&data[acc])^
        acc += size_of(u32be)
    }
    sidx.reserved = (^u16be)(&data[acc])^
    acc += size_of(u16be)
    sidx.reference_count = (^u16be)(&data[acc])^
    acc += size_of(u16be)
    sidx.items = make([]SegmentIndexBoxItems, sidx.reference_count)

    for i:=0; i < int(sidx.reference_count); i+=1 {
        tmp: u32be = (^u32be)(&data[acc])^
        sidx.items[i].reference_type = (byte)((tmp & 0x00000001))
        sidx.items[i].referenced_size = tmp >> 1
        acc += size_of(u32be)
        sidx.items[i].subsegment_duration = (^u32be)(&data[acc])^
        acc += size_of(u32be)
        tmp = (^u32be)(&data[acc])^
        sidx.items[i].starts_with_SAP = (byte)((tmp & 0x00000001))
        sidx.items[i].SAP_type = (byte)((tmp & 0x000000E0))
        sidx.items[i].SAP_delta_time = tmp >> 4
        acc += size_of(u32be)
    }
    return sidx, acc
}

serialize_sidx :: proc(sidx: Sidx) ->  (data: []byte) {
    fullbox_b := serialize_fullbox(sidx.fullbox)
    reference_ID := sidx.reference_ID
    reference_ID_b := (^[4]byte)(&reference_ID)^
    data = slice.concatenate([][]byte{fullbox_b[:], reference_ID_b[:]})
    timescale := sidx.timescale
    timescale_b := (^[4]byte)(&timescale)^
    data = slice.concatenate([][]byte{data[:], timescale_b[:]})
    if sidx.fullbox.version == 1 {
        earliest_presentation_time_extends := sidx.earliest_presentation_time_extends
        earliest_presentation_time_extends_b := (^[8]byte)(&earliest_presentation_time_extends)^
        data = slice.concatenate([][]byte{data[:], earliest_presentation_time_extends_b[:]})

        first_offset_extends := sidx.first_offset_extends
        first_offset_extends_b := (^[4]byte)(&first_offset_extends)^
        data = slice.concatenate([][]byte{data[:], first_offset_extends_b[:]})
    }else {
        earliest_presentation_time := sidx.earliest_presentation_time
        earliest_presentation_time_b := (^[4]byte)(&earliest_presentation_time)^
        data = slice.concatenate([][]byte{data[:], earliest_presentation_time_b[:]})

        first_offset := sidx.first_offset
        first_offset_b := (^[4]byte)(&first_offset)^
        data = slice.concatenate([][]byte{data[:], first_offset_b[:]})
    }

    reserved := sidx.reserved
    reserved_b := (^[2]byte)(&reserved)^
    data = slice.concatenate([][]byte{data[:], reserved_b[:]})

    reference_count := sidx.reference_count
    reference_count_b := (^[2]byte)(&reference_count)^
    data = slice.concatenate([][]byte{data[:], reference_count_b[:]})
    for i:=0; i < int(sidx.reference_count); i+=1 {
        reference_type := sidx.items[i].reference_type
        reference_type_u32be := u32be(reference_type)
        reference_type_u32be = reference_type_u32be & 0x00000001
        referenced_size := sidx.items[i].referenced_size
        referenced_size = referenced_size << 1
        tmp := reference_type_u32be | referenced_size
        tmp_b := (^[4]byte)(&tmp)^
        data = slice.concatenate([][]byte{data[:], tmp_b[:]})
        subsegment_duration := sidx.items[i].subsegment_duration
        subsegment_duration_b := (^[4]byte)(&subsegment_duration)^
        data = slice.concatenate([][]byte{data[:], subsegment_duration_b[:]})
        starts_with_SAP := sidx.items[i].starts_with_SAP
        starts_with_SAP_u32 := u32be(starts_with_SAP)
        //starts_with_SAP_u32 = starts_with_SAP_u32 & 0x00000001
        SAP_type := sidx.items[i].SAP_type
        SAP_type_u32be := u32be(SAP_type)
        SAP_type_u32be = SAP_type_u32be << 1
        //SAP_type_u32be = SAP_type_u32be & 0x000000FE
        SAP_delta_time := sidx.items[i].SAP_delta_time
        SAP_delta_time =  SAP_delta_time << 4
        tmp = starts_with_SAP_u32 | SAP_type_u32be  | SAP_delta_time
        tmp_b = (^[4]byte)(&tmp)^
        data = slice.concatenate([][]byte{data[:], tmp_b[:]})
    }
    return data
}