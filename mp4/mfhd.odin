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

write_mfhd :: proc(handle: os.Handle, atom: MfhdV2) -> FileError {
    data := bytes.Buffer{}
	atom_cpy := atom
    bytes.buffer_init(&data, []u8{})
    bytes.buffer_write_ptr(&data, &atom_cpy.sequence_number, 4)
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
