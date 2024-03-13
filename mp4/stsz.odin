package mp4

import "core:slice"
import "core:mem"
import "core:os"
import "core:fmt"
import "core:bytes"

// SampleSizeBox
Stsz :: struct {
    fullbox:        FullBox,
    sample_size:    u32be,
    sample_count:   u32be,
    entries_sizes:  []u32be
}

StszV2 :: struct {
    box:                BoxV2,
    sample_size:        u32be,
    sample_count:       u32be,
    entries:      []u32be
}

read_stsz :: proc(handle: os.Handle, id: int = 1) -> (atom: StszV2, err: FileError) {
    box := select_box(handle, "stsz", id) or_return
    atom.box = box
    fseek(handle, i64(box.header_size), os.SEEK_CUR) or_return
    buffer := [4]u8{}
    fread(handle, buffer[:]) or_return
    atom.sample_size = transmute(u32be)buffer
    fread(handle, buffer[:]) or_return
    atom.sample_count = transmute(u32be)buffer
	entries_b := make([]u8, atom.sample_count * 4)
    fread(handle, entries_b[:]) or_return
    atom.entries = (transmute([]u32be)entries_b)[:atom.sample_count]
    return atom, nil
}

write_stsz :: proc(handle: os.Handle, atom: StszV2) -> FileError {
    data := bytes.Buffer{}
	atom_cpy := atom
    bytes.buffer_init(&data, []u8{})
    bytes.buffer_write_ptr(&data, &atom_cpy.sample_size, 4)
    bytes.buffer_write_ptr(&data, &atom_cpy.sample_count, 4)
    bytes.buffer_write_ptr(&data, &atom_cpy.entries,
	size_of(u32be) * int(atom_cpy.sample_count))
    write_box(handle, atom_cpy.box) or_return
    total_write := fwrite(handle, bytes.buffer_to_bytes(&data)) or_return
    bytes.buffer_destroy(&data)
	return nil
}

deserialize_stsz :: proc(data: []byte) -> (stsz: Stsz, acc: u64) {
    // Stts main values
    fullbox, fullbox_size :=  deserialize_fullbox(data[acc:])
    stsz.fullbox = fullbox
    acc += fullbox_size
    stsz.sample_size = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    stsz.sample_count = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    if stsz.sample_size == 0 {
        stsz.entries_sizes = make([]u32be, stsz.sample_count)
        for i:=0; i<int(stsz.sample_count); i+=1 {
            stsz.entries_sizes[i] = (^u32be)(&data[acc])^
            acc += size_of(u32be)
        }
    }
    return stsz, acc
}

serialize_stsz :: proc(stsz: Stsz) -> (data: []byte){
    fullbox_b := serialize_fullbox(stsz.fullbox)
    sample_size := stsz.sample_size
    sample_size_b := (^[4]byte)(&sample_size)^
    data = slice.concatenate([][]byte{fullbox_b[:], sample_size_b[:]})
    sample_count := stsz.sample_count
    sample_count_b := (^[4]byte)(&sample_count)^
    data = slice.concatenate([][]byte{data[:], sample_count_b[:]})
    for i:=0;i<int(sample_count);i+=1{
        entry := stsz.entries_sizes[i]
        entry_b := (^[4]byte)(&entry)^
        data = slice.concatenate([][]byte{data[:], entry_b[:]})
    }
    // if sample_count > 0 {
    //     entries_sizes := stsz.entries_sizes
    //     entries_sizes_b := mem.ptr_to_bytes(&entries_sizes, size_of(u32be)*int(sample_count))
    //     data = slice.concatenate([][]byte{data[:], entries_sizes_b[:]})
    // }
    return data
}
