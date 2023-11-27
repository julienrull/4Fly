package mp4

import "core:fmt"
import "core:strings"
import "core:mem"
import "core:math"
import "core:slice"
import "core:os"


to_string :: proc(value: ^u32be) -> string {
    value_b := (^byte)(value)
    str := strings.string_from_ptr(value_b, size_of(u32be))
    return str
}

print_box :: proc(box: Box){
    type := box.type
    type_b := (^byte)(&type)
    fmt.println("Type:", strings.string_from_ptr(type_b, size_of(u32be)))
    fmt.println("Size:", box.size)
}

print_mp4_level :: proc(name: string, level: int){
    str := ""
    err: mem.Allocator_Error
    i := 0
    for i < level - 1 {
        a := [?]string { str, "-"}
        str, err = strings.concatenate(a[:])
        i=i+1
    }
    a := [?]string { str, name}
    str, err = strings.concatenate(a[:])
    fmt.println(str, level)
}

dump :: proc(data: []byte, size: u64, level: int = 0) -> (offset: u64) { 
    lvl := level + 1
    for offset < size {
        box, box_size := deserialize_box(data[offset:])
        type_s := to_string(&box.type)
        _, ok := BOXES[type_s]
        if ok {
            print_mp4_level(type_s, lvl)
            offset += dump(data[offset + box_size:], u64(box.size) - box_size, lvl) + box_size
        }else{
            offset = size
        }
    }
    return offset
}

recreate_seg_1 :: proc(index: int, video: []byte, seg1: []byte){

    time: f32 = 3.75375
    seg1_atom, seg1_atom_size  := deserialize_mp4(seg1, u64(len(seg1)))
    video_atom, video_atom_size  := deserialize_mp4(video, u64(len(video)))
    // *** READ SAMPLES ***

    // * Time coordinate system
    timescale := video_atom.moov.traks[0].mdia.mdhd.timescale
    video_duration := video_atom.moov.traks[0].mdia.mdhd.duration / timescale
    // * Get Sample Index
    sample_count := video_atom.moov.traks[0].mdia.minf.stbl.stts.entries[0].sample_count
    sample_duration := f32(video_atom.moov.traks[0].mdia.minf.stbl.stts.entries[0].sample_delta) / f32(timescale)
    sample_index1 :=  math.max(0, int((f32(index)-1) * time / sample_duration) - 1)

    sample_index2 :=  math.max(0, int(f32(index) * time / sample_duration) - 1)
    fmt.println(sample_index1)
    fmt.println(sample_index2)

    sample_counter := 0
    // * Get chunk
    // chunk_index := 0
    // for i:=0;i<int(video_atom.moov.traks[0].mdia.minf.stbl.stsc.entry_count);i+=1 {
    //     if sample_counter >= semple_index {
    //         chunk_index = i 
    //         break
    //     }
    //     sample_counter += int(video_atom.moov.traks[0].mdia.minf.stbl.stsc.entries[i].samples_per_chunk)
    // }
    // fmt.println("chunk_index", chunk_index)
    // * Get chunk offset
    
    chunk_offsets := video_atom.moov.traks[0].mdia.minf.stbl.stco.chunks_offsets[sample_index1:sample_index1]
    sample_sizes := video_atom.moov.traks[0].mdia.minf.stbl.stsz.entries_sizes[sample_index2:sample_index2]
    seg1_atom.mdat.data = {}
    for i:=0;i<len(chunk_offsets);i+=1 {
        data := video[chunk_offsets[i]:chunk_offsets[i] + sample_sizes[i]]
        seg1_atom.mdat.data = slice.concatenate([][]byte{seg1_atom.mdat.data,data})
    }
    
    new_seg1_b := serialize_mp4(seg1_atom)
    
    file, err := os.open(fmt.tprintf("./test5/output/video/avc1/seg-%d.m4s", index), os.O_CREATE)
    if err != os.ERROR_NONE {
        panic("FILE ERROR")
    }
    defer os.close(file)
    os.write(file,  new_seg1_b)
}