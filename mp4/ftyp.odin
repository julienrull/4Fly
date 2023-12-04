package mp4

import "core:slice"

// FileTypeBox
Ftyp :: struct { // ftyp && styp
    box:          Box,
    major_brand:        u32be,
    minor_version:      u32be,
    compatible_brands:  []u32be,
}


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