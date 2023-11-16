package mp4

import "core:slice"
import "core:fmt"

// EditListBox
Elst :: struct { // edts -> elst
    fullbox:        FullBox,
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

deserialize_elst :: proc(data: []byte) -> (elst: Elst, acc: u64) {
    fullbox, fullbox_size :=  deserialize_fullbox(data[acc:])
    elst.fullbox = fullbox
    acc += fullbox_size
    elst.entry_count = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    elst.entries = make([]EditListBoxEntries, elst.entry_count)
    for i:=0; i<int(elst.entry_count); i+=1 {
        if elst.fullbox.version == 1 {
            elst.entries[i].segment_duration_extends = (^u64be)(&data[acc])^
            acc += size_of(u64be)
            elst.entries[i].media_time_extends = (^i64be)(&data[acc])^
            acc += size_of(i64be)
        }else {
            elst.entries[i].segment_duration = (^u32be)(&data[acc])^
            acc += size_of(u32be)
            elst.entries[i].media_time = (^i32be)(&data[acc])^
            acc += size_of(i32be)
        }
        elst.entries[i].media_rate_integer = (^i16be)(&data[acc])^
        acc += size_of(i16be)
        elst.entries[i].media_rate_fraction = (^i16be)(&data[acc])^
        acc += size_of(i16be)
    }
    return elst, acc
}


serialize_elst :: proc(elst: Elst) -> (data: []byte) {
    fullbox_b := serialize_fullbox(elst.fullbox)
    entry_count := elst.entry_count
    entry_count_b := (^[4]byte)(&entry_count)^
    data = slice.concatenate([][]byte{fullbox_b[:], entry_count_b[:]})
    for i:=0; i<int(elst.entry_count); i+=1 {
        if elst.fullbox.version == 1 {
            segment_duration_extends := elst.entries[i].segment_duration_extends
            segment_duration_extends_b :=  (^[8]byte)(&segment_duration_extends)^
            data = slice.concatenate([][]byte{data[:], segment_duration_extends_b[:]})
            media_time_extends := elst.entries[i].media_time_extends
            media_time_extends_b :=  (^[8]byte)(&media_time_extends)
            data = slice.concatenate([][]byte{data[:], media_time_extends_b[:]})
        }else {
            segment_duration := elst.entries[i].segment_duration
            segment_duration_b :=  (^[4]byte)(&segment_duration)^
            data = slice.concatenate([][]byte{data[:], segment_duration_b[:]})
            media_time := elst.entries[i].media_time
            media_time_b :=  (^[4]byte)(&media_time)
            data = slice.concatenate([][]byte{data[:], media_time_b[:]})
        }
        media_rate_integer := elst.entries[i].media_rate_integer
        media_rate_integer_b := (^[2]byte)(&media_rate_integer)
        data = slice.concatenate([][]byte{data[:], media_rate_integer_b[:]})
        media_rate_fraction := elst.entries[i].media_rate_fraction
        media_rate_fraction_b := (^[2]byte)(&media_rate_fraction)
        data = slice.concatenate([][]byte{data[:], media_rate_fraction_b[:]})
    }
    return data
}