# BACKLOGS

- MP4 to M4S / MP4 to Fragmented MP

# TODO

## Deserialization / Srilization

- [x] Dump MP4 / M4S files

- [-] Fragment deserialization / serialization
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
  - [x] moov
    - [x] mvhd
    - [x] trak
      - [x] tkhd
      - [x] edts
        - [x] elst
      - [x] mdia
        - [x] mdhd
        - [x] hdlr
        - [x] minf
          - [x] nmhd
          - [x] hmhd
          - [x] smhd
          - [x] vmhd
          - [x] dinf
            - [x] dref
          - [-] stbl
            - [x] stts
            - [x] ctts
            - [-] stsd
            - [x] stsz
            - [x] stz2
            - [x] stsc
            - [x] stco
            - [x] co64
            - [x] stss
            - [x] stsh
            - [x] stdp
            - [x] padb
            - [x] sbgp
            - [x] sgpd
          - [x] edts
            - [x] elst
          - [x] udta
            - [x] cprt
          - [x] mvex
            - [x] mehd
            - [x] trex
  - [ ] free
  - [x] mdat

  - [x] box.Size == 0, 1 or size
  - [x] check if all boxes with bitwises are corrcect because of Big endian format
  - [x] stbl need hdlr type info (vide, soun and hint) info  sub boxes "stsd" and "stdp"
  - [x] fragment boxes  need some modularity rewriting
  - [ ] serialize mp4
     - [x] "sgpd" and "sbgp"
  - [ ] "stsd" seems need an "avc1" special atom as children but not document in specs
  - [ ] Insert box
  - [ ] Try create an init file for test.mp4
    (https://thompsonng.blogspot.com/2010/11/mp4-file-format-part-2.html)
  - [ ] We need to check the box size if this one is the last of the file. It isn't a problem with "mdat" because we already check for it (it cause error "out of bound at index 0")
  - [ ] ftyp minor_version doesn't seems to correspond with mp4box

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
