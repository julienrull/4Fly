package mp4

// EditListBox
Elst :: struct { // edts -> elst
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

