package mp4

import "core:mem"
import "core:slice"
import "core:os"
import "core:bytes"

Tfdt :: struct {
    fullbox: FullBox,
    baseMediaDecodeTime: u32be,
    baseMediaDecodeTime_extends: u64be
}


TfdtV2 :: struct {
    box: BoxV2,
    baseMediaDecodeTime: u64be,
}


read_tfdt :: proc(handle: os.Handle, id: int = 1) -> (atom: TfdtV2, error: FileError) {
    atom.box = select_box(handle, "tfdt", id) or_return
    total_seek := fseek(handle, i64(atom.box.header_size), os.SEEK_CUR) or_return
    buffer := [8]u8{}
    if atom.box.version == 1 {
        fread(handle, buffer[:]) or_return
        atom.baseMediaDecodeTime = (transmute(u64be)buffer)
    }else {
        fread(handle, buffer[:4]) or_return
        atom.baseMediaDecodeTime = u64be((transmute([]u32be)buffer[:4])[0])
    }
    return atom, nil
}

write_tfdt :: proc(handle: os.Handle, atom: TfdtV2) -> FileError {
    data := bytes.Buffer{}
	atom_cpy := atom
    bytes.buffer_init(&data, []u8{})
    if atom.box.version == 1 {
        bytes.buffer_write_ptr(&data, &atom_cpy.baseMediaDecodeTime, 8)
    }else {
        baseMediaDecodeTime := u32(atom_cpy.baseMediaDecodeTime)
        bytes.buffer_write_ptr(&data, &baseMediaDecodeTime, 4)
    }
    write_box(handle, atom_cpy.box) or_return
    total_write := fwrite(handle, bytes.buffer_to_bytes(&data)) or_return
    bytes.buffer_destroy(&data)
	return nil
}

deserialize_tfdt :: proc(data: []byte) -> (tfdt: Tfdt, acc: u64) {
    fullbox, fullbox_size := deserialize_fullbox(data)
    tfdt.fullbox = fullbox
    acc += fullbox_size
    if fullbox.version == 1 {
        tfdt.baseMediaDecodeTime_extends = (^u64be)(&data[acc])^
        acc += size_of(u64be)
    }else{
        tfdt.baseMediaDecodeTime = (^u32be)(&data[acc])^
        acc += size_of(u32be)
    }
    return tfdt, acc
}

serialize_tfdt :: proc(tfdt: Tfdt) -> (data: []byte){
    fullbox_b := serialize_fullbox(tfdt.fullbox)
    if tfdt.fullbox.version == 1 {
        baseMediaDecodeTime_extends := tfdt.baseMediaDecodeTime_extends
        baseMediaDecodeTime_extends_b := (^[8]byte)(&baseMediaDecodeTime_extends)^
        data = slice.concatenate([][]byte{fullbox_b[:], baseMediaDecodeTime_extends_b[:]})
    }else{
        baseMediaDecodeTime := tfdt.baseMediaDecodeTime
        baseMediaDecodeTime_b := (^[4]byte)(&baseMediaDecodeTime)^
        data = slice.concatenate([][]byte{fullbox_b[:], baseMediaDecodeTime_b[:]})
    }
    return data
}
