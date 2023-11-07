# BACKLOGS
- MP4 to M4S / MP4 to Fragmented MP

# TODO
- Deserialization / Srilization
[x] Dump MP4 / M4S files
[ ] deserialization / serialization
    [x] styp
    [-] sidx (serialization)
    [-] moof (serialization)
        [x] mfhd
        [-] traf (serialization)
            [x] tfhd
            [-] trun (serialization)
            [-] tfdt (serialization)
    [-] stbl
        [x] stts
        [x] ctts
        [x] stsd
        [x] stsz
        [x] stz2
        [x] stsc
        [x] stco
        [x] co64
        [x] stss
        [x] stsh
        [x] stdp
        [x] padb
        [ ] sgpd
        [ ] sbgp
    [x] edts
        [x] elst
    [x] udta
        [x] cprt
    [x] mvex
        [x] mehd
        [x] trex
    [ ] free
    [ ] mdat

# Done
- Dumping

# Note

// The sample flags field in sample fragments (default_sample_flags here and in a Track Fragment Header
// Box, and sample_flags and first_sample_flags in a Track Fragment Run Box) is coded as a 32-bit
// value. It has the following structure:
// bit(6) reserved=0;
// unsigned int(2) sample_depends_on;
// unsigned int(2) sample_is_depended_on;
// unsigned int(2) sample_has_redundancy;
// bit(3) sample_padding_value;
// bit(1) sample_is_difference_sample;
//  // i.e. when 1 signals a non-key or non-sync sample
// unsigned int(16) sample_degradation_priority;
// The sample_depends_on, sample_is_depended_on and sample_has_redundancy values are defined as
// documented in the Independent and Disposable Samples Box.
// The sample_padding_value is defined as for the padding bits table. The sample_degradation_priority is
// defined as for the degradation priority table.