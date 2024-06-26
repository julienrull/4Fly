package mp4

import "core:mem"
import "core:slice"
import "core:os"
import "core:bytes"

// TrackExtendsBox
Trex :: struct {
    fullbox                            : FullBox,
    track_ID                           : u32be,
    default_sample_description_index   : u32be,
    default_sample_duration            : u32be,
    default_sample_size                : u32be,
    default_sample_flags               : u32be,
}


TrexV2 :: struct {
    box                                : BoxV2,
    track_ID                           : u32be,
    default_sample_description_index   : u32be,
    default_sample_duration            : u32be,
    default_sample_size                : u32be,
    default_sample_flags               : u32be,
}

read_Trex :: proc(handle: os.Handle, id: int = 1) -> (atom: TrexV2, error: FileError) {
    atom.box = select_box(handle, "trex", id) or_return
    total_seek := fseek(handle, i64(atom.box.header_size), os.SEEK_CUR) or_return
    buffer := [4]u8{}
    fread(handle, buffer[:]) or_return
    atom.track_ID = transmute(u32be)buffer
    fread(handle, buffer[:]) or_return
    atom.default_sample_description_index = transmute(u32be)buffer
    fread(handle, buffer[:]) or_return
    atom.default_sample_duration = transmute(u32be)buffer
    fread(handle, buffer[:]) or_return
    atom.default_sample_size = transmute(u32be)buffer
    fread(handle, buffer[:]) or_return
    atom.default_sample_flags = transmute(u32be)buffer
    return atom, nil
}

write_trex :: proc(handle: os.Handle, atom: TrexV2) -> FileError {
    data := bytes.Buffer{}
	atom_cpy := atom
    bytes.buffer_init(&data, []u8{})
    bytes.buffer_write_ptr(&data, &atom_cpy.track_ID, 4)
    bytes.buffer_write_ptr(&data, &atom_cpy.default_sample_description_index, 4)
    bytes.buffer_write_ptr(&data, &atom_cpy.default_sample_duration, 4)
    bytes.buffer_write_ptr(&data, &atom_cpy.default_sample_size, 4)
    bytes.buffer_write_ptr(&data, &atom_cpy.default_sample_flags, 4)
    write_box(handle, atom_cpy.box) or_return
    total_write := fwrite(handle, bytes.buffer_to_bytes(&data)) or_return
    bytes.buffer_destroy(&data)
	return nil
}

deserialize_trex :: proc(data: []byte) -> (trex: Trex, acc: u64) {
    fullbox, fullbox_size := deserialize_fullbox(data[acc:])
    trex.fullbox = fullbox
    acc += fullbox_size
    trex.track_ID = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    trex.default_sample_description_index = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    trex.default_sample_duration = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    trex.default_sample_size = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    trex.default_sample_flags = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    return trex, acc
}

serialize_trex :: proc(trex: Trex) -> (data: []byte) {
    fullbox_b := serialize_fullbox(trex.fullbox)
    track_ID := trex.track_ID
    track_ID_b := (^[4]byte)(&track_ID)^
    data = slice.concatenate([][]byte{fullbox_b[:], track_ID_b[:]})

    default_sample_description_index := trex.default_sample_description_index
    default_sample_description_index_b := (^[4]byte)(&default_sample_description_index)^
    data = slice.concatenate([][]byte{data[:], default_sample_description_index_b[:]})

    default_sample_duration := trex.default_sample_duration
    default_sample_duration_b := (^[4]byte)(&default_sample_duration)^
    data = slice.concatenate([][]byte{data[:], default_sample_duration_b[:]})

    default_sample_size := trex.default_sample_size
    default_sample_size_b := (^[4]byte)(&default_sample_size)^
    data = slice.concatenate([][]byte{data[:], default_sample_size_b[:]})

    default_sample_flags := trex.default_sample_flags
    default_sample_flags_b := (^[4]byte)(&default_sample_flags)^
    data = slice.concatenate([][]byte{data[:], default_sample_flags_b[:]})

    return data
}
