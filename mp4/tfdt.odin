package mp4

import "core:mem"
import "core:slice"

Tfdt :: struct {
    fullbox: FullBox,
    baseMediaDecodeTime: u32be,
    baseMediaDecodeTime_extends: u64be
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