package mp4

// SampleDescriptionBox
Stsd :: struct { // stbl -> stsd
    fullbox:                FullBox,
    entry_count:            u32be,
    hintSampleEntries:      [dynamic]HintSampleEntry,
    visualSampleEntries:    [dynamic]VisualSampleEntry,
    audioSampleEntries:     [dynamic]AudioSampleEntry
}


deserialize_stsd :: proc(data: []byte, handler_type: string) -> (stsd: Stsd, acc: u64) {
    fullbox, fullbox_size       :=  deserialize_fullbox(data[acc:])
    stsd.fullbox                = fullbox
    acc                         += fullbox_size
    stsd.entry_count            = (^u32be)(&data[acc])^
    acc                         += size_of(u32be)
    stsd.hintSampleEntries      = make([dynamic]HintSampleEntry, 0, 6)
    stsd.visualSampleEntries    = make([dynamic]VisualSampleEntry, 0, 6)
    stsd.audioSampleEntries     = make([dynamic]AudioSampleEntry, 0, 6)
    for i:=0; i<int(stsd.entry_count); i+=1 {
        switch handler_type {
            case "hint":
                append(&(stsd.hintSampleEntries), (^HintSampleEntry)(&data[acc])^)
                acc += size_of(HintSampleEntry)
            case "vide":
                append(&(stsd.visualSampleEntries), (^VisualSampleEntry)(&data[acc])^)
                acc += size_of(VisualSampleEntry)
            case "soun":
                append(&(stsd.audioSampleEntries), (^AudioSampleEntry)(&data[acc])^)
                acc += size_of(AudioSampleEntry)
        }
    }
    return stsd, acc
}

serialize_stsd :: proc(stsd: Stsd, handler_type: string) -> (data: []byte) {
    panic("[TODO] - serialize_stsd() not implemented")
    //return data
}


SampleEntry :: struct {
    box:                    Box,
    reserved:               [6]byte,
    data_reference_index:   u16be
}

HintSampleEntry :: struct {
    using sampleEntry:  SampleEntry,
    data:               []byte
}

VisualSampleEntry :: struct {
     using sampleEntry:     SampleEntry,
     pre_defined:           u16be, // = 0
     reserved2:              u16be,  // = 0
     pre_defined2:          [3]u32be,  // = 0
     width:                 u16be,
     height:                u16be,
     horizresolution:       u32be, // = 0x00480000 72 dpi
     vertresolution:        u32be, // = 0x00480000; // 72 dpi
     reserved3:             u32be, // = 0;
     frame_count:           u16be, // = 1;
     compressorname:        [32]byte, // string[32]
     depth:                 u16be, // = 0x0018;
     pre_defined3:          i16be // = -1;
}

AudioSampleEntry :: struct {
    using sampleEntry:  SampleEntry,
    reserved2:          [2]u32be, //= 0
    channelcount:       u16be, // = 2;
    samplesize:         u16be, // = 16;
    pre_defined:        u16be, // = 0;
    reserved3:          u16be, // = 0 ;
    samplerate:         u32be // = {timescale of media}<<16;
}