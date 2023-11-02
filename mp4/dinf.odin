package mp4

// DataInformationBox
Dinf :: struct { // minf -> dinf
    box:    Box,
}

DataReferenceBox :: struct { // dinf -> dref
    fullBox:        FullBox,
    entry_count:    u32be,
    urls:           []DataEntryUrlBox,
    urns:           []DataEntryUrnBox
}

DataEntryUrlBox :: struct { // dinf -> url
    fullBox:    FullBox,
    location: string
}

DataEntryUrnBox :: struct { // dinf -> urn
    fullBox:    FullBox,
    name:       string,
    location:   string
}