package mp4

// CompositionOffsetBox
Ctts :: struct{ // stbl -> ctts
    fullBox:        FullBox,
    entry_count:    u32be,
    entries :       []CompositionOffsetBoxEntries
}

CompositionOffsetBoxEntries :: struct {
    sample_count: u32be,
    sample_offset: u32be
}