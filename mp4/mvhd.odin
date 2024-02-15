package mp4

import "core:slice"
import "core:os"
import "core:log"

// MovieHeaderBox
Mvhd :: struct {  // moov -> mvhd
    fullbox:                    FullBox,
    creation_time:              u32be,
    modification_time:          u32be,
    timescale:                  u32be,
    duration:                   u32be,
    creation_time_extends:      u64be,
    modification_time_extends:  u64be,
    duration_extends:           u64be,
    rate:                       i32be,
    volume:                     i16be,
    reserved:                   i16be,
    reserved2: [2]u32be,
    matrixx: [9]i32be,
    pre_defined: [6]i32be,
    next_track_ID: u32be,
}


MvhdV2 :: struct {  // moov -> mvhd
    box:                    BoxV2,
    creation_time:      u64be,
    modification_time:  u64be,
    timescale:          u32be,
    duration:           u64be,
    rate:               i32be,
    volume:             i16be,
    matrixx: [9]i32be,
    next_track_ID: u32be,
}

read_mvhd :: proc(handle: os.Handle, id: int = 1) -> (atom: MvhdV2, err: FileError) {
    box := select_box(handle, "mvhd", id) or_return
    atom.box = box
    total_seek := fseek(handle, i64(box.header_size), os.SEEK_CUR) or_return
    buffer := [8]u8{}
    if box.version == 1 {
        fread(handle, buffer[:]) or_return
        atom.creation_time = transmute(u64be)buffer
        fread(handle, buffer[:]) or_return
        atom.modification_time = transmute(u64be)buffer
        fread(handle, buffer[:4]) or_return
        atom.timescale = (transmute([]u32be)buffer[:4])[0]
        fread(handle, buffer[:]) or_return
        atom.duration = transmute(u64be)buffer
    }else{
        fread(handle, buffer[:4]) or_return
        atom.creation_time = u64be((transmute([]u32be)buffer[:4])[0])
        fread(handle, buffer[:4]) or_return
        atom.modification_time = u64be((transmute([]u32be)buffer[:4])[0])
        fread(handle, buffer[:4]) or_return
        atom.timescale = (transmute([]u32be)buffer[:4])[0]
        fread(handle, buffer[:4]) or_return
        atom.duration = u64be((transmute([]u32be)buffer[:4])[0])
    }
    fread(handle, buffer[:4]) or_return
    atom.rate = (transmute([]i32be)buffer[:4])[0]
    fread(handle, buffer[:2]) or_return
    atom.volume = (transmute([]i16be)buffer[:2])[0]
    fseek(handle, 10, os.SEEK_CUR)
    buffer2 := [36]u8{}
    fread(handle, buffer2[:]) or_return
    atom.matrixx = transmute([9]i32be)buffer2
    fseek(handle, 24, os.SEEK_CUR)
    fread(handle, buffer[:4]) or_return
    atom.next_track_ID = (transmute([]u32be)buffer[:4])[0]
    return atom, nil
}

deserialize_mvhd :: proc(data: []byte) -> (mvhd: Mvhd, acc: u64){
    fullbox, fullbox_size := deserialize_fullbox(data[acc:])
    mvhd.fullbox = fullbox
    acc += fullbox_size
    if fullbox.version == 1 {
        mvhd.creation_time_extends = (^u64be)(&data[acc])^
        acc += size_of(u64be)
        mvhd.modification_time_extends = (^u64be)(&data[acc])^
        acc += size_of(u64be)
        mvhd.timescale = (^u32be)(&data[acc])^
        acc += size_of(u32be)
        mvhd.duration_extends = (^u64be)(&data[acc])^
        acc += size_of(u64be)
    }else {
        mvhd.creation_time = (^u32be)(&data[acc])^
        acc += size_of(u32be)
        mvhd.modification_time = (^u32be)(&data[acc])^
        acc += size_of(u32be)
        mvhd.timescale = (^u32be)(&data[acc])^
        acc += size_of(u32be)
        mvhd.duration = (^u32be)(&data[acc])^
        acc += size_of(u32be)
    }

    mvhd.rate = (^i32be)(&data[acc])^
    acc += size_of(i32be)

    mvhd.volume = (^i16be)(&data[acc])^
    acc += size_of(i16be)

    mvhd.reserved = (^i16be)(&data[acc])^
    acc += size_of(i16be)

    mvhd.reserved2 = (^[2]u32be)(&data[acc])^
    acc += size_of([2]u32be)

    mvhd.matrixx = (^[9]i32be)(&data[acc])^
    acc += size_of([9]i32be)

    mvhd.pre_defined = (^[6]i32be)(&data[acc])^
    acc += size_of([6]i32be)

    mvhd.next_track_ID = (^u32be)(&data[acc])^
    acc += size_of(u32be)

    return mvhd, acc
}

serialize_mvhd :: proc(mvhd: Mvhd) -> (data: []byte){
    fullbox_b := serialize_fullbox(mvhd.fullbox)
    if mvhd.fullbox.version == 1 {
        creation_time_extends :=  mvhd.creation_time_extends
        creation_time_extends_b :=  (^[8]byte)(&creation_time_extends)^
        data = slice.concatenate([][]byte{fullbox_b[:], creation_time_extends_b[:]})
        modification_time_extends :=  mvhd.modification_time_extends
        modification_time_extends_b :=  (^[8]byte)(&modification_time_extends)^
        data = slice.concatenate([][]byte{data[:], modification_time_extends_b[:]})
        timescale :=  mvhd.timescale
        timescale_b :=  (^[4]byte)(&timescale)^
        data = slice.concatenate([][]byte{data[:], timescale_b[:]})
        duration_extends :=  mvhd.duration_extends
        duration_extends_b :=  (^[8]byte)(&duration_extends)^
        data = slice.concatenate([][]byte{data[:], duration_extends_b[:]})
    }else {
        creation_time :=  mvhd.creation_time
        creation_time_b :=  (^[4]byte)(&creation_time)^
        data = slice.concatenate([][]byte{fullbox_b[:], creation_time_b[:]})
        modification_time :=  mvhd.modification_time
        modification_time_b :=  (^[4]byte)(&modification_time)^
        data = slice.concatenate([][]byte{data[:], modification_time_b[:]})
        timescale :=  mvhd.timescale
        timescale_b :=  (^[4]byte)(&timescale)^
        data = slice.concatenate([][]byte{data[:], timescale_b[:]})
        duration :=  mvhd.duration
        duration_b :=  (^[4]byte)(&duration)^
        data = slice.concatenate([][]byte{data[:], duration_b[:]})
    }

    rate :=  mvhd.rate
    rate_b :=  (^[4]byte)(&rate)^
    data = slice.concatenate([][]byte{data[:], rate_b[:]})

    volume :=  mvhd.volume
    volume_b :=  (^[2]byte)(&volume)^
    data = slice.concatenate([][]byte{data[:], volume_b[:]})

    reserved :=  mvhd.reserved
    reserved_b :=  (^[2]byte)(&reserved)^
    data = slice.concatenate([][]byte{data[:], reserved_b[:]})

    reserved2 :=  mvhd.reserved2
    reserved2_b :=  (^[8]byte)(&reserved2)^
    data = slice.concatenate([][]byte{data[:], reserved2_b[:]})

    matrixx :=  mvhd.matrixx
    matrixx_b :=  (^[36]byte)(&matrixx)^
    data = slice.concatenate([][]byte{data[:], matrixx_b[:]})

    pre_defined :=  mvhd.pre_defined
    pre_defined_b :=  (^[24]byte)(&pre_defined)^
    data = slice.concatenate([][]byte{data[:], pre_defined_b[:]})

    next_track_ID :=  mvhd.next_track_ID
    next_track_ID_b :=  (^[4]byte)(&next_track_ID)^
    data = slice.concatenate([][]byte{data[:], next_track_ID_b[:]})

    return data
}
