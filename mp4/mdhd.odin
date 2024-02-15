package mp4

import "core:slice"
import "core:os"
import "core:strings"

// MediaHeaderBox
Mdhd :: struct {
	// mdia -> mdhd
	fullbox:                   FullBox,
	creation_time:             u32be,
	creation_time_extends:     u64be,
	modification_time:         u32be,
	modification_time_extends: u64be,
	timescale:                 u32be,
	duration:                  u32be,
	duration_extends:          u64be,
	pad:                       byte, // 1 bit
	language:                  [3]byte, // unsigned int(5)[3]
	pre_defined:               u16be,
}

MdhdV2 :: struct {
	box:                        BoxV2,
	creation_time:              u64be,
	modification_time:          u64be,
	timescale:                  u32be,
	duration:                   u64be,
	//pad:                       byte, // 1 bit
	language:                   string, // unsigned int(5)[3]
	//pre_defined:               u16be,
}

read_mdhd :: proc(handle: os.Handle, id: int = 1) -> (atom: MdhdV2, err: FileError) {
    box := select_box(handle, "mdhd", id) or_return
    atom.box = box
    total_seek := fseek(handle, i64(box.header_size), os.SEEK_CUR) or_return
    buffer := [8]u8{}
    if box.version == 1 {
        fread(handle, buffer[:]) or_return
        atom.creation_time = transmute(u64be)buffer
        fread(handle, buffer[:]) or_return
        atom.modification_time = transmute(u64be)buffer
        fread(handle, buffer[:4]) or_return
        atom.timescale = (transmute([]u32be)buffer[:4])[0]
        fread(handle, buffer[:]) or_return
        atom.duration = transmute(u64be)buffer
    }else{
        fread(handle, buffer[:4]) or_return
        atom.creation_time = u64be((transmute([]u32be)buffer[:4])[0])
        fread(handle, buffer[:4]) or_return
        atom.modification_time = u64be((transmute([]u32be)buffer[:4])[0])
        fread(handle, buffer[:4]) or_return
        atom.timescale = (transmute([]u32be)buffer[:4])[0]
        fread(handle, buffer[:4]) or_return
        atom.duration = u64be((transmute([]u32be)buffer[:4])[0])
    }
    fread(handle, buffer[:2]) or_return
    // TODO: can't get language
    language_b := [3]u8{}
    temp := (transmute([]u16be)buffer[:2])[0]
    language_b[0] = u8((temp >> 10) & 0b00000000_00011111)
    language_b[1] = u8((temp >> 5) & 0b00000000_00011111)
    language_b[2] = u8(temp & 0b00000000_00011111)
    atom.language = strings.clone_from_bytes(language_b[:])
    fseek(handle, 2, os.SEEK_CUR) or_return
    return atom, nil
}

deserialize_mdhd :: proc(data: []byte) -> (mdhd: Mdhd, acc: u64){
    fullbox, fullbox_size := deserialize_fullbox(data[acc:])
    mdhd.fullbox = fullbox
    acc += fullbox_size
    if fullbox.version == 1 {
        mdhd.creation_time_extends = (^u64be)(&data[acc])^
        acc += size_of(u64be)
        mdhd.modification_time_extends = (^u64be)(&data[acc])^
        acc += size_of(u64be)
        mdhd.timescale = (^u32be)(&data[acc])^
        acc += size_of(u32be)
        mdhd.duration_extends = (^u64be)(&data[acc])^
        acc += size_of(u64be)
    }else {
        mdhd.creation_time = (^u32be)(&data[acc])^
        acc += size_of(u32be)
        mdhd.modification_time = (^u32be)(&data[acc])^
        acc += size_of(u32be)
        mdhd.timescale = (^u32be)(&data[acc])^
        acc += size_of(u32be)
        mdhd.duration = (^u32be)(&data[acc])^
        acc += size_of(u32be)
    }
    packed := (^u16be)(&data[acc])^
    mdhd.pad = byte(packed & 0x0001)
    mdhd.language[2] = byte((packed >> 1) & 0x1F)
    mdhd.language[1] = byte((packed >> 6) & 0x1F)
    mdhd.language[0] = byte((packed >> 11) & 0x1F)
    acc += size_of(u16be)
    mdhd.pre_defined = (^u16be)(&data[acc])^
    acc += size_of(u16be)
    return mdhd, acc
}

serialize_mdhd :: proc(mdhd: Mdhd) -> (data: []byte){
    fullbox_b := serialize_fullbox(mdhd.fullbox)
    if mdhd.fullbox.version == 1 {
        creation_time_extends :=  mdhd.creation_time_extends
        creation_time_extends_b :=  (^[8]byte)(&creation_time_extends)^
        data = slice.concatenate([][]byte{fullbox_b[:], creation_time_extends_b[:]})
        modification_time_extends :=  mdhd.modification_time_extends
        modification_time_extends_b :=  (^[8]byte)(&modification_time_extends)^
        data = slice.concatenate([][]byte{data[:], modification_time_extends_b[:]})
        timescale :=  mdhd.timescale
        timescale_b :=  (^[4]byte)(&timescale)^
        data = slice.concatenate([][]byte{data[:], timescale_b[:]})
        duration_extends :=  mdhd.duration_extends
        duration_extends_b :=  (^[8]byte)(&duration_extends)^
        data = slice.concatenate([][]byte{data[:], duration_extends_b[:]})
    }else {
        creation_time :=  mdhd.creation_time
        creation_time_b :=  (^[4]byte)(&creation_time)^
        data = slice.concatenate([][]byte{fullbox_b[:], creation_time_b[:]})
        modification_time :=  mdhd.modification_time
        modification_time_b :=  (^[4]byte)(&modification_time)^
        data = slice.concatenate([][]byte{data[:], modification_time_b[:]})
        timescale :=  mdhd.timescale
        timescale_b :=  (^[4]byte)(&timescale)^
        data = slice.concatenate([][]byte{data[:], timescale_b[:]})
        duration :=  mdhd.duration
        duration_b :=  (^[4]byte)(&duration)^
        data = slice.concatenate([][]byte{data[:], duration_b[:]})
    }

    packed: u16be = 0
    packed = packed | u16be(mdhd.pad)
    packed = packed | (u16be(mdhd.language[2]) <<  1)
    packed = packed | (u16be(mdhd.language[1]) <<  6)
    packed = packed | (u16be(mdhd.language[2]) <<  12)
    packed_b := (^[2]byte)(&packed)^
    data = slice.concatenate([][]byte{data[:], packed_b[:]})

    pre_defined :=  mdhd.pre_defined
    pre_defined_b :=  (^[2]byte)(&pre_defined)^
    data = slice.concatenate([][]byte{data[:], pre_defined_b[:]})
    return data
}
