package mp4

import "core:mem"
import "core:slice"
import "core:os"
import "core:bytes"

// TrackFragmentHeaderBox
Tfhd :: struct { // traf -> tfhd
    fullbox:                    FullBox,
    track_ID:                   u32be,
    // all the following are optional fields
    base_data_offset:           u64be,
    sample_description_index:   u32be,
    default_sample_duration:    u32be,
    default_sample_size:        u32be,
    default_sample_flags:       u32be
}

// FLAGS
BASE_DATA_OFFSET_PRESENT            :: 0x000001
SAMPLE_DESCRIPTION_INDEX_PRESENT    :: 0x000002
DEFAULT_SAMPLE_DURATION_PRESENT     :: 0x000008
DEFAULT_SAMPLE_SIZE_PRESENT         :: 0x000010
DEFAULT_SAMPLE_FLAGS_PRESENT        :: 0x000020
DURATION_IS_EMPTY                   :: 0x010000

TfhdV2 :: struct {
    box:                                BoxV2,
    track_ID:                           u32be,
    // BOOL FLAGS
    base_data_offset_present:           bool,
    sample_description_index_present:   bool,
    default_sample_duration_present:    bool,
    default_sample_size_present:        bool,
    default_sample_flags_present:       bool,
    duration_is_empty:                  bool,
    // all the following are optional fields
    base_data_offset:                   u64be,
    sample_description_index:           u32be,
    default_sample_duration:            u32be,
    default_sample_size:                u32be,
    default_sample_flags:               u32be,
}

read_tfhd :: proc(handle: os.Handle) -> (atom: TfhdV2, error: FileError) {
    atom.box = select_box(handle, "tfhd") or_return
    total_seek := fseek(handle, i64(atom.box.header_size), os.SEEK_CUR) or_return
    buffer := [8]u8{}
    fread(handle, buffer[:4]) or_return
    atom.track_ID = (transmute([]u32be)buffer[:4])[0]
    if u32be(atom.box.flags[2]) & BASE_DATA_OFFSET_PRESENT            == BASE_DATA_OFFSET_PRESENT {
        fread(handle, buffer[:]) or_return
        atom.base_data_offset = transmute(u64be)buffer
        atom.base_data_offset_present = true
    }
    if u32be(atom.box.flags[2]) & SAMPLE_DESCRIPTION_INDEX_PRESENT    == SAMPLE_DESCRIPTION_INDEX_PRESENT {
        fread(handle, buffer[:4]) or_return
        atom.sample_description_index = (transmute([]u32be)buffer[:4])[0]
        atom.sample_description_index_present = true
     }
    if u32be(atom.box.flags[2]) & DEFAULT_SAMPLE_DURATION_PRESENT     == DEFAULT_SAMPLE_DURATION_PRESENT {
        fread(handle, buffer[:4]) or_return
        atom.default_sample_duration = (transmute([]u32be)buffer[:4])[0]
        atom.default_sample_duration_present = true
    }
    if u32be(atom.box.flags[2]) & DEFAULT_SAMPLE_SIZE_PRESENT         == DEFAULT_SAMPLE_SIZE_PRESENT {
        fread(handle, buffer[:4]) or_return
        atom.default_sample_size = (transmute([]u32be)buffer[:4])[0]
        atom.default_sample_size_present = true
    }
    if u32be(atom.box.flags[2]) & DEFAULT_SAMPLE_FLAGS_PRESENT        == DEFAULT_SAMPLE_FLAGS_PRESENT {
        fread(handle, buffer[:4]) or_return
        atom.default_sample_flags = (transmute([]u32be)buffer[:4])[0]
        atom.default_sample_flags_present = true
    }
    if u32be(atom.box.flags[0]) & DURATION_IS_EMPTY                   == DURATION_IS_EMPTY {
        atom.duration_is_empty = true
    }
    return atom, nil
}

write_tfhd :: proc(handle: os.Handle, atom: TfhdV2, is_large_size: bool = false) -> FileError {
    data := bytes.Buffer{}
	atom_cpy := atom
	atom_cpy.box.is_container = false
	atom_cpy.box.version = 0
	atom_cpy.box.is_fullbox = true
	atom_cpy.box.is_large_size = is_large_size
	atom_cpy.box.total_size = 0
	atom_cpy.box.header_size = 12
	atom_cpy.box.body_size = 4
    if is_large_size {
        atom_cpy.box.header_size += 8
    }
    bytes.buffer_init(&data, []u8{})
    bytes.buffer_write_ptr(&data, &atom_cpy.track_ID, 4)

    if atom_cpy.base_data_offset_present {
        atom_cpy.box.flags[0] |= u8(BASE_DATA_OFFSET_PRESENT)
        bytes.buffer_write_ptr(&data, &atom_cpy.base_data_offset, 8)
	    atom_cpy.box.body_size += 8
    }
    if atom_cpy.sample_description_index_present {
        atom_cpy.box.flags[0] |= u8(SAMPLE_DESCRIPTION_INDEX_PRESENT)
        bytes.buffer_write_ptr(&data, &atom_cpy.sample_description_index, 4)
	    atom_cpy.box.body_size += 4
    }
    if atom_cpy.default_sample_duration_present {
        atom_cpy.box.flags[0] |= u8(TFHD_DEFAULT_SAMPLE_DURATION_PRESENT)
        bytes.buffer_write_ptr(&data, &atom_cpy.default_sample_duration, 4)
	    atom_cpy.box.body_size += 4
    }
    if atom_cpy.default_sample_size_present {
        atom_cpy.box.flags[0] |= u8(DEFAULT_SAMPLE_SIZE_PRESENT)
        bytes.buffer_write_ptr(&data, &atom_cpy.default_sample_size, 4)
	    atom_cpy.box.body_size += 4
    }
    if atom_cpy.default_sample_flags_present {
        atom_cpy.box.flags[0] |= u8(DEFAULT_SAMPLE_FLAGS_PRESENT)
        bytes.buffer_write_ptr(&data, &atom_cpy.default_sample_flags, 4)
	    atom_cpy.box.body_size += 4
    }
    if atom_cpy.duration_is_empty {
        atom_cpy.box.flags[2] |= u8(DURATION_IS_EMPTY >> 16)
        // TODO: ???
    }

    atom_cpy.box.total_size = atom_cpy.box.header_size + atom_cpy.box.body_size
    write_box(handle, atom_cpy.box) or_return
    total_write := fwrite(handle, bytes.buffer_to_bytes(&data)) or_return
    bytes.buffer_destroy(&data)
	return nil
}

deserialize_tfhd :: proc(data: []byte) -> (tfhd: Tfhd, acc: u64) {
    fullbox, fullbox_size := deserialize_fullbox(data)
    tfhd.fullbox = fullbox
    acc += fullbox_size
    tfhd.track_ID = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    opt1_flags := tfhd.fullbox.flags[2]
    opt3_flags := tfhd.fullbox.flags[0]
    is_base_data_offset_present := bool(opt1_flags & 0b00000001)
    is_sample_description_index_present := bool(opt1_flags & 0b00000010)
    is_default_sample_duration_present := bool(opt1_flags & 0b00001000)
    is_default_sample_size_present := bool(opt1_flags & 0b00010000)
    is_default_sample_flags_present  := bool(opt1_flags & 0b00100000)
    duration_is_empty := bool(opt3_flags & 0b00000001)
    if is_base_data_offset_present {
        tfhd.base_data_offset = (^u64be)(&data[acc])^
        acc += size_of(u64be)
    }
    if is_sample_description_index_present {
        tfhd.sample_description_index = (^u32be)(&data[acc])^
        acc += size_of(u32be)
    }
    if is_default_sample_duration_present {
        tfhd.default_sample_duration = (^u32be)(&data[acc])^
        acc += size_of(u32be)
    }
    if is_default_sample_size_present {
        tfhd.default_sample_size = (^u32be)(&data[acc])^
        acc += size_of(u32be)
    }
    if is_default_sample_flags_present {
        tfhd.default_sample_flags = (^u32be)(&data[acc])^
        acc += size_of(u32be)
    }
    // if duration_is_empty {

    // }
    return tfhd, acc
}

serialize_tfhd :: proc(tfhd: Tfhd) -> (data: []byte) {
    fullbox_b := serialize_fullbox(tfhd.fullbox)
    track_ID := tfhd.track_ID
    track_ID_b := (^[4]byte)(&track_ID)^
    data = slice.concatenate([][]byte{fullbox_b[:], track_ID_b[:]})
    opt1_flags := tfhd.fullbox.flags[2]
    opt3_flags := tfhd.fullbox.flags[0]
    is_base_data_offset_present := bool(opt1_flags & 0b00000001)
    is_sample_description_index_present := bool(opt1_flags & 0b00000010)
    is_default_sample_duration_present := bool(opt1_flags & 0b00001000)
    is_default_sample_size_present := bool(opt1_flags & 0b00010000)
    is_default_sample_flags_present  := bool(opt1_flags & 0b00100000)
    duration_is_empty := bool(opt3_flags & 0b00000001)
    if is_base_data_offset_present {
        base_data_offset := tfhd.base_data_offset
        base_data_offset_b := (^[8]byte)(&base_data_offset)^
        data = slice.concatenate([][]byte{data[:], base_data_offset_b[:]})
    }
    if is_sample_description_index_present {
        sample_description_index := tfhd.sample_description_index
        sample_description_index_b := (^[4]byte)(&sample_description_index)^
        data = slice.concatenate([][]byte{data[:], sample_description_index_b[:]})
    }
    if is_default_sample_duration_present {
        default_sample_duration := tfhd.default_sample_duration
        default_sample_duration_b := (^[4]byte)(&default_sample_duration)^
        data = slice.concatenate([][]byte{data[:], default_sample_duration_b[:]})
    }
    if is_default_sample_size_present {
        default_sample_size := tfhd.default_sample_size
        default_sample_size_b := (^[4]byte)(&default_sample_size)^
        data = slice.concatenate([][]byte{data[:], default_sample_size_b[:]})
    }
    if is_default_sample_flags_present {
        default_sample_flags := tfhd.default_sample_flags
        default_sample_flags_b := (^[4]byte)(&default_sample_flags)^
        data = slice.concatenate([][]byte{data[:], default_sample_flags_b[:]})
    }
    // if duration_is_empty {

    // }
    return data
}
