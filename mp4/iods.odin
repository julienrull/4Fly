package mp4


import "core:slice"
import "core:fmt"

Iods :: struct {
    fullbox: FullBox,
    unknow_content:   []byte
}

deserialize_iods :: proc(data: []byte) -> (iods: Iods, acc: u64){
    fullbox, fullbox_size := deserialize_fullbox(data[acc:])
    iods.fullbox = fullbox
    acc += fullbox_size
    size: u64
    if fullbox.box.size == 1 {
        size = u64(fullbox.box.largesize)
    }else if fullbox.box.size == 0 {
        size = u64(len(data))        
    } else {
        size = u64(fullbox.box.size)
    }
    
    remain := size - acc

    iods.unknow_content = data[acc: acc + remain]
    
    acc += remain
    fmt.println("acc:", acc)
    return iods, acc
}

serialize_iods :: proc(iods: Iods) -> (data: []byte){
    fullbox_b := serialize_fullbox(iods.fullbox)
    data = slice.concatenate([][]byte{fullbox_b[:], iods.unknow_content[:]})
    fmt.println("len(data):", len(data))
    return data
}