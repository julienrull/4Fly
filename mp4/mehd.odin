package mp4
import "core:mem"
import "core:slice"

// MovieExtendsHeaderBox
Mehd :: struct {
    fullbox:                        FullBox,
    fragment_duration:             u32be,
    fragment_duration_extends:     u64be,
}

deserialize_mehd :: proc(data: []byte) -> (mehd: Mehd, acc: u64) {
    fullbox, fullbox_size := deserialize_fullbox(data[acc:])
    mehd.fullbox = fullbox
    acc += fullbox_size
    if fullbox.version == 1 {
        mehd.fragment_duration = (^u32be)(&data[acc])^
        acc += size_of(u32be)
    }else{
        mehd.fragment_duration_extends = (^u64be)(&data[acc])^
        acc += size_of(u64be)
    }
    return mehd, acc
}

serialize_mehd :: proc(mehd: Mehd) -> (data: []byte) {
    fullbox_b := serialize_fullbox(mehd.fullbox)
    if mehd.fullbox.version == 1 {
        fragment_duration_extends := mehd.fragment_duration_extends
        fragment_duration_extends_b := (^[8]byte)(&fragment_duration_extends)^
        data = slice.concatenate([][]byte{fullbox_b[:], fragment_duration_extends_b[:]})
    }else{
        fragment_duration := mehd.fragment_duration
        fragment_duration_b := (^[4]byte)(&fragment_duration)^
        data = slice.concatenate([][]byte{fullbox_b[:], fragment_duration_b[:]})
    }
    return data
}