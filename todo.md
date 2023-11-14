# BACKLOGS

- MP4 to M4S / MP4 to Fragmented MP

# TODO

## Deserialization / Srilization

- [x] Dump MP4 / M4S files
- [-] Fragment deserialization / serialization (need some modularity rewriting)
  - [x] styp
  - [x] sidx
  - [x] moof
    - [x] mfhd
    - [x] traf
      - [x] tfhd
      - [x] trun
      - [x] tfdt

---

- [ ] Video deserialization / serialization

  - [x] ftyp
  - [ ] moov
    - [ ] mvhd
    - [ ] trak
      - [ ] tkhd
      - [x] edts
        - [x] elst
      - [ ] mdia
        - [ ] mdhd
        - [ ] hdlr
        - [x] minf
          - [x] nmhd
          - [x] hmhd
          - [x] smhd
          - [x] vmhd
          - [x] dinf
            - [x] dref
          - [-] stbl ("stsd" and "stdp" need deserialize and serialize need additional sibling values)
            - [x] stts
            - [x] ctts
            - [x] stsd
            - [x] stsz
            - [x] stz2
            - [x] stsc
            - [x] stco
            - [x] co64
            - [x] stss
            - [x] stsh
            - [x] stdp
            - [x] padb
            - [ ] sgpd
            - [ ] sbgp
          - [x] edts
            - [x] elst
          - [x] udta
            - [x] cprt
          - [x] mvex
            - [x] mehd
            - [x] trex
  - [ ] free
  - [x] mdat

  - [ ] box.Size == 0, 1, size

# Done

## Dumping

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
// // i.e. when 1 signals a non-key or non-sync sample
// unsigned int(16) sample_degradation_priority;
// The sample_depends_on, sample_is_depended_on and sample_has_redundancy values are defined as
// documented in the Independent and Disposable Samples Box.
// The sample_padding_value is defined as for the padding bits table. The sample_degradation_priority is
// defined as for the degradation priority table.

opt : edts, dinf

- composition time (CT)

- decoding time (DT)

- ctts -> sample_offset = CT(n) = DT(n) + CTTS(n).
