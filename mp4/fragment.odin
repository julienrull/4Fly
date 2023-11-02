package mp4

Fragment :: struct {
    styp:   Ftyp,
    sidxs:   [dynamic]Sidx,
    moof:   Moof,
    mdat:   Mdat
}

deserialize_fragment :: proc(data: []byte) ->  (Fragment, u64) {
    acc: u64 = 0
    styp, styp_size := deserialize_ftype(data)
    acc += styp_size
    sidxs := make([dynamic]Sidx, 0, 16)
    box, box_size := deserialize_box(data[acc:])
    name := to_string(&box.type)
    for name == "sidx" {
        sidx, sidx_size := deserialize_sidx(data[acc:])
        append(&sidxs, sidx)
        acc += sidx_size
        box, box_size = deserialize_box(data[acc:])
        name = to_string(&box.type)
    }
    moof, moof_size := deserialize_moof(data[acc:])
    acc += moof_size
    mdat, mdat_size := deserialize_mdat(data[acc:])
    acc += mdat_size
    return Fragment{
        styp,
        sidxs,
        moof,
        mdat
    }, acc
}
