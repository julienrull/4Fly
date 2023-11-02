package mp4

// TrackFragmentBox
Traf :: struct { // moof -> traf
    box:    Box,
    tfhd:   Tfhd,
    trun:   Trun
}

deserialize_traf :: proc(data: []byte) -> (Traf, u64) {
    size: u64 = 0
    box, box_size := deserialize_box(data)
    if box.size == 1 {
        size = u64(box.largesize)
    }else if box.size == 0{
        size = u64(len(data))
    }else {
        size = u64(box.size)
    }
    tfhd, tfhd_size := deserialize_tfhd(data[box_size:])
    trun, trun_size := deserialize_trun(data[box_size + tfhd_size:])
    return Traf{ box, tfhd, trun}, size
}