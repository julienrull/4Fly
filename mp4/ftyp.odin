package mp4

import "core:slice"
import "core:os"
import "core:strings"
import "core:bytes"

// FileTypeBox
Ftyp :: struct { // ftyp && styp
    box:          Box,
    major_brand:        u32be,
    minor_version:      u32be,
    compatible_brands:  []u32be,
}

FtypV2 :: struct {
    box: BoxV2,
    major_brand: string,
    minor_version: u32be,
    compatible_brands:  []string,
}

read_ftyp :: proc(handle: os.Handle) -> (atom: FtypV2, total_read: int, err: FileError) {
    box := select_box(handle, "ftyp") or_return
    atom.box = box
    total_seek := fseek(handle, i64(box.header_size), os.SEEK_CUR) or_return
    buffer := [4]u8{}
    total_read += fread(handle, buffer[:]) or_return
    atom.major_brand =  strings.clone_from_bytes(buffer[:])
    total_read += fread(handle, buffer[:]) or_return
    atom.minor_version =  transmute(u32be)buffer
    compatible_brands_count := (box.body_size - u64be(total_read)) / 4
    atom.compatible_brands = make([]string, compatible_brands_count)
    for i in 0..<compatible_brands_count {
        total_read += fread(handle, buffer[:]) or_return
        atom.compatible_brands[i] = strings.clone_from_bytes(buffer[:])
    }
    return atom, total_read, nil
}

write_ftyp :: proc(handle: os.Handle, ftyp: FtypV2) -> FileError {
    data := bytes.Buffer{}
    bytes.buffer_init(&data, []u8{})
    write_box(handle, ftyp.box)
    // TODO: write ftyp body
    major_brand := ftyp.major_brand
    major_brand_b := transmute([]u8)major_brand
    major_brand_n := (^u32be)(&major_brand_b[0])^
    bytes.buffer_write_ptr(&data, &major_brand_n, 4)
    minor_version := ftyp.minor_version
    bytes.buffer_write_ptr(&data, &minor_version, 4)
    compatible_brands := ftyp.compatible_brands
    compatible_brands_b := transmute([]u8)compatible_brands
    compatible_brands_n := transmute([]u32be)compatible_brands_b
    for i in 0..<len(compatible_brands) {
        brand := compatible_brands[i]
        brand_b := transmute([]u8)brand
        brand_n := (^u32be)(&brand_b[0])^
        bytes.buffer_write_ptr(&data, &brand_n, 4)
    }
    // TODO: handle io error for buffer_to_bytes
    total_write := fwrite(handle, bytes.buffer_to_bytes(&data)) or_return
    bytes.buffer_destroy(&data)
    return nil
}

// TODO: use an arena memory
free_ftyp :: proc(atom: ^FtypV2) {
    for i in 0..<len(atom.compatible_brands) {
        free(&atom.compatible_brands[i])
    }
    free(&atom.compatible_brands)
    free(&atom.major_brand)
}

// ######################################################################################
serialize_ftype :: proc(ftyp: Ftyp) -> (data: []byte){
    box_b := serialize_box(ftyp.box)
    major_brand := ftyp.major_brand
    major_brand_b := (^[4]byte)(&major_brand)^
    data = slice.concatenate([][]byte{box_b, major_brand_b[:]})
    minor_version := ftyp.minor_version
    minor_version_b := (^[4]byte)(&minor_version)^
    data = slice.concatenate([][]byte{data, minor_version_b[:]})
    for i:=0;i<len(ftyp.compatible_brands);i+=1 {
        brand := ftyp.compatible_brands[i]
        brand_b := (^[4]byte)(&brand)^
        data = slice.concatenate([][]byte{data, brand_b[:]})
    }
    return data
}

deserialize_ftype :: proc(data: []byte) -> (ftyp: Ftyp, acc: u64) {
    box, box_size := deserialize_box(data)
    ftyp.box = box
    acc += box_size
    ftyp.major_brand = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    ftyp.minor_version = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    know_size := box_size + size_of(u32be)*2
    remain_size: u64 = 0
    if box.size == 1 {
        remain_size = (u64)(box.largesize) - know_size
    }else{
        remain_size = (u64)(box.size) - know_size
    }
    compatible_brands_b := data[acc:]
    ftyp.compatible_brands = make([]u32be, remain_size / size_of(u32be))
    i: u64 = 0
    for i < remain_size / u64(size_of(u32be)) {
        brand := (^u32be)(&compatible_brands_b[i*4])^
        ftyp.compatible_brands[i] = brand
        i=i+1
    }
    acc += remain_size
    return ftyp, acc
}

create_fragment_styp :: proc() -> (data: []byte) {
    box := Box{24, 1937013104, 0, [16]byte{}}
    styp := Ftyp{box, 1836278888, 0, []u32be{1836278888, 1836280184}}
    data = serialize_ftype(styp)
    return data
}
