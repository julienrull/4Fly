package mp4

import "core:fmt"
import "core:mem"
import "core:slice"
import "core:os"
import "core:bytes"

// TrackRunBox
Trun :: struct { // traf -> trun
    fullbox:                FullBox,
    sample_count:           u32be,
    // the following are optional fields
    data_offset:            i32be,
    first_sample_flags:     u32be,
    // all fields in the following array are optional
    samples:                []TrackRunBoxSample
}

TrackRunBoxSample :: struct {
    sample_duration:                    u32be,
    sample_size:                        u32be,
    sample_flags:                       u32be,
    sample_composition_time_offset:     u32be,
}


DATA_OFFSET_PRESENT                     :: 0x000001
FIRST_SAMPLE_FLAGS_PRESENT              :: 0x000004
SAMPLE_DURATION_PRESENT                 :: 0x000100
SAMPLE_SIZE_PRESENT                     :: 0x000200
SAMPLE_FLAGS_PRESENT                    :: 0x000400
SAMPLE_COMPOSITION_TIME_OFFSET_PRESENT  :: 0x000800

TrunV2 :: struct { // traf -> trun
    box:                                        BoxV2,
    sample_count:                               u32be,
    data_offset:                                i32be,
    first_sample_flags:                         u32be,
    samples:                                    []TrackRunBoxSample,

   data_offset_present:                         bool,
   first_sample_flags_present:                  bool,
   sample_duration_present:                     bool,
   sample_size_present:                         bool,
   sample_flags_present:                        bool,
   sample_composition_time_offset_present:      bool,
}

read_trun :: proc(handle: os.Handle, id: int = 1) -> (atom: TrunV2, error: FileError) {
    atom.box = select_box(handle, "trun", id) or_return
    total_seek := fseek(handle, i64(atom.box.header_size), os.SEEK_CUR) or_return
    buffer := [4]u8{}
    fread(handle, buffer[:]) or_return
    atom.sample_count = transmute(u32be)buffer
    if atom.box.flags[2] & DATA_OFFSET_PRESENT                   == DATA_OFFSET_PRESENT {
        fread(handle, buffer[:]) or_return
        atom.data_offset = transmute(i32be)buffer
        atom.data_offset_present = true
    }
    if atom.box.flags[2] & FIRST_SAMPLE_FLAGS_PRESENT            == FIRST_SAMPLE_FLAGS_PRESENT {
        fread(handle, buffer[:]) or_return
        atom.first_sample_flags = transmute(u32be)buffer
        atom.first_sample_flags_present = true
    }
    atom.samples = make([]TrackRunBoxSample, atom.sample_count)
    for i in 0..<atom.sample_count {
        if (atom.box.flags[1] & (SAMPLE_DURATION_PRESENT >> 8)) == (SAMPLE_DURATION_PRESENT >> 8){
            fread(handle, buffer[:]) or_return
            atom.samples[i].sample_duration = transmute(u32be)buffer
            atom.sample_duration_present = true
        }
        if (atom.box.flags[1] & (SAMPLE_SIZE_PRESENT >> 8)) == (SAMPLE_SIZE_PRESENT  >> 8){
            fread(handle, buffer[:]) or_return
            atom.samples[i].sample_size = transmute(u32be)buffer
            atom.sample_size_present = true
        }
        if (atom.box.flags[1] & (SAMPLE_FLAGS_PRESENT >> 8)) == (SAMPLE_FLAGS_PRESENT  >> 8){
            fread(handle, buffer[:]) or_return
            atom.samples[i].sample_flags = transmute(u32be)buffer
            atom.sample_flags_present = true
        }
        if (atom.box.flags[1] & (SAMPLE_COMPOSITION_TIME_OFFSET_PRESENT >> 8)) == (SAMPLE_COMPOSITION_TIME_OFFSET_PRESENT  >> 8){
            fread(handle, buffer[:]) or_return
            atom.samples[i].sample_composition_time_offset = transmute(u32be)buffer
            atom.sample_composition_time_offset_present = true
        }
    }
    return atom, nil
}

write_trun :: proc(handle: os.Handle, atom: TrunV2, is_large_size: bool = false) -> FileError {
    data := bytes.Buffer{}
	atom_cpy := atom
	atom_cpy.box.is_container = false
	atom_cpy.box.version = 0
	atom_cpy.box.is_fullbox = true
	atom_cpy.box.is_large_size = is_large_size
	atom_cpy.box.total_size = 0
	atom_cpy.box.header_size = 12
	atom_cpy.box.body_size = 4
    atom_cpy.box.flags = [3]u8{}
    if is_large_size {
        atom_cpy.box.header_size += 8
    }
    bytes.buffer_init(&data, []u8{})
    bytes.buffer_write_ptr(&data, &atom_cpy.sample_count, 4)
    if atom_cpy.data_offset_present {
        atom_cpy.box.flags[2] |= u8(DATA_OFFSET_PRESENT)
        bytes.buffer_write_ptr(&data, &atom_cpy.data_offset, 4)
	    atom_cpy.box.body_size += 4
    }
    if atom_cpy.first_sample_flags_present {
        atom_cpy.box.flags[2] |= u8(FIRST_SAMPLE_FLAGS_PRESENT)
        bytes.buffer_write_ptr(&data, &atom_cpy.first_sample_flags, 4)
	    atom_cpy.box.body_size += 4
    }
    for i in 0..<atom_cpy.sample_count {
        if atom_cpy.sample_duration_present {
            atom_cpy.box.flags[1] |= u8(SAMPLE_DURATION_PRESENT >> 8)
            bytes.buffer_write_ptr(&data, &atom_cpy.samples[i].sample_duration, 4)
            atom_cpy.box.body_size += 4
        }
        if atom_cpy.sample_size_present {
            atom_cpy.box.flags[1] |= u8(SAMPLE_SIZE_PRESENT >> 8)
            bytes.buffer_write_ptr(&data, &atom_cpy.samples[i].sample_size, 4)
            atom_cpy.box.body_size += 4
        }
        if atom_cpy.sample_flags_present {
            atom_cpy.box.flags[1] |= u8(SAMPLE_FLAGS_PRESENT >> 8)
            bytes.buffer_write_ptr(&data, &atom_cpy.samples[i].sample_flags, 4)
            atom_cpy.box.body_size += 4
        }
        if atom_cpy.sample_composition_time_offset_present {
            atom_cpy.box.flags[1] |= u8(SAMPLE_COMPOSITION_TIME_OFFSET_PRESENT >> 8)
            bytes.buffer_write_ptr(&data, &atom_cpy.samples[i].sample_composition_time_offset, 4)
            atom_cpy.box.body_size += 4
        }
    }
    //atom_cpy.box.flags[0] = 0
    atom_cpy.box.total_size = atom_cpy.box.header_size + atom_cpy.box.body_size
    write_box(handle, atom_cpy.box) or_return
    total_write := fwrite(handle, bytes.buffer_to_bytes(&data)) or_return
    bytes.buffer_destroy(&data)
    fmt.println(atom_cpy.box.flags)
	return nil
}

deserialize_trun :: proc(data: []byte) -> (trun: Trun, acc: u64) {
    fullbox, fullbox_size := deserialize_fullbox(data)
    trun.fullbox = fullbox
    acc += fullbox_size
    trun.sample_count = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    opt1_flags := trun.fullbox.flags[2]
    is_data_offset_present := bool(opt1_flags & 0b00000001)
    is_first_sample_flags_present := bool(opt1_flags & 0b00000100)
    if is_data_offset_present {
        trun.data_offset = (^i32be)(&data[acc])^
        acc += size_of(i32be)
    }
    if is_first_sample_flags_present {
        trun.first_sample_flags = (^u32be)(&data[acc])^
        acc += size_of(u32be)
    }
    opt2_flags := trun.fullbox.flags[1]
    is_sample_duration_present := bool(opt2_flags & 0b00000001)
    is_sample_size_present := bool(opt2_flags & 0b00000010)
    is_sample_flags_present := bool(opt2_flags & 0b00000100)
    is_sample_composition_time_offsets_present := bool(opt2_flags & 0b00001000)
    trun.samples = make([]TrackRunBoxSample, trun.sample_count)
    if trun.sample_count > 0 {
        for i:=0; i < int(trun.sample_count); i+=1 {
            if is_sample_duration_present {
                trun.samples[i].sample_duration = (^u32be)(&data[acc])^
                acc = acc + size_of(u32be)
            }
            if is_sample_size_present {
                trun.samples[i].sample_size = (^u32be)(&data[acc])^
                acc = acc + size_of(u32be)
            }
            if is_sample_flags_present {
                trun.samples[i].sample_flags = (^u32be)(&data[acc])^
                acc = acc + size_of(u32be)
            }
            if is_sample_composition_time_offsets_present {
                trun.samples[i].sample_composition_time_offset = (^u32be)(&data[acc])^
                acc = acc + size_of(u32be)
            }
        }
    }
    return trun, acc
}

serialize_trun :: proc(trun: Trun) -> (data: []byte) {
    fullbox_b := serialize_fullbox(trun.fullbox)
    sample_count := trun.sample_count
    sample_count_b := (^[4]byte)(&sample_count)^
    data = slice.concatenate([][]byte{fullbox_b[:], sample_count_b[:]})
    opt1_flags := trun.fullbox.flags[2]
    is_data_offset_present := bool(opt1_flags & 0b00000001)
    is_first_sample_flags_present := bool(opt1_flags & 0b00000100)
    if is_data_offset_present {
        data_offset := trun.data_offset
        data_offset_b := (^[4]byte)(&data_offset)^
        data = slice.concatenate([][]byte{data[:], data_offset_b[:]})
    }
    if is_first_sample_flags_present {
        first_sample_flags := trun.first_sample_flags
        first_sample_flags_b := (^[4]byte)(&first_sample_flags)^
        data = slice.concatenate([][]byte{data[:], first_sample_flags_b[:]})
    }
    opt2_flags := trun.fullbox.flags[1]
    is_sample_duration_present := bool(opt2_flags & 0b00000001)
    is_sample_size_present := bool(opt2_flags & 0b00000010)
    is_sample_flags_present := bool(opt2_flags & 0b00000100)
    is_sample_composition_time_offsets_present := bool(opt2_flags & 0b00001000)
    if trun.sample_count > 0 {
        for i:=0; i < int(trun.sample_count); i+=1 {
            if is_sample_duration_present {
                sample_duration := trun.samples[i].sample_duration
                sample_duration_b := (^[4]byte)(&sample_duration)^
                data = slice.concatenate([][]byte{data[:], sample_duration_b[:]})
            }
            if is_sample_size_present {
                sample_size := trun.samples[i].sample_size
                sample_size_b := (^[4]byte)(&sample_size)^
                data = slice.concatenate([][]byte{data[:], sample_size_b[:]})
            }
            if is_sample_flags_present {
                sample_flags := trun.samples[i].sample_flags
                sample_flags_b := (^[4]byte)(&sample_flags)^
                data = slice.concatenate([][]byte{data[:], sample_flags_b[:]})
            }
            if is_sample_composition_time_offsets_present {
                sample_composition_time_offset := trun.samples[i].sample_composition_time_offset
                sample_composition_time_offset_b := (^[4]byte)(&sample_composition_time_offset)^
                data = slice.concatenate([][]byte{data[:], sample_composition_time_offset_b[:]})
            }
        }
    }
    return data
}
