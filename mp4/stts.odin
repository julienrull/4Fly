package mp4

// TimeToSampleBox
Stts :: struct{ // stbl -> stts
    fullBox:        FullBox,
    entry_count:    u32be,
    entries :       []TimeToSampleBoxEntries
}

TimeToSampleBoxEntries :: struct {
    sample_count: u32be,
    sample_delta: u32be
}
