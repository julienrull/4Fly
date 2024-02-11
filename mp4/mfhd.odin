package mp4

import "core:mem"
import "core:slice"
import "core:fmt"
import "core:os"
import "core:bytes"

// MovieFragmentHeaderBox
Mfhd :: struct { // moof -> mfhd
    fullbox:            FullBox,
    sequence_number:    u32be
}


MfhdV2 :: struct { // moof -> mfhd
    box:                BoxV2,
    sequence_number:    u32be
}

read_mfhd :: proc(handle: os.Handle) -> (atom: MfhdV2, error: FileError) {
    atom.box = select_box(handle, "mfhd") or_return
    total_seek := fseek(handle, i64(atom.box.header_size), os.SEEK_CUR) or_return
    buffer := [4]u8{}
    total_read := fread(handle, buffer[:]) or_return
    atom.sequence_number =  transmute(u32be)buffer
    return atom, nil
}

write_mfhd :: proc(handle: os.Handle, atom: MfhdV2, is_large_size: bool = false) -> FileError {
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
    bytes.buffer_write_ptr(&data, &atom_cpy.sequence_number, 4)
    atom_cpy.box.total_size = atom_cpy.box.header_size + atom_cpy.box.body_size
    write_box(handle, atom_cpy.box) or_return
    total_write := fwrite(handle, bytes.buffer_to_bytes(&data)) or_return
    bytes.buffer_destroy(&data)
	return nil
}

deserialize_mfhd :: proc(data: []byte) -> (mfhd: Mfhd, acc: u64) {
    fullbox, fullbox_size := deserialize_fullbox(data)
    mfhd.fullbox = fullbox
    acc += fullbox_size
    mfhd.sequence_number = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    return mfhd, acc
}

serialize_mfhd :: proc(mfhd: Mfhd) -> (data: []byte) {
    fullbox_b := serialize_fullbox(mfhd.fullbox)
    sequence_number := mfhd.sequence_number
    sequence_number_b := (^[4]byte)(&sequence_number)^
    data = slice.concatenate([][]byte{fullbox_b[:], sequence_number_b[:]})
    return data
}
