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
    fmt.println(len(seg1))
    time: f32 = 3.753750 // 3,753750
    seg1_atom, seg1_atom_size  := deserialize_mp4(seg1, u64(len(seg1)))
    video_atom, video_atom_size  := deserialize_mp4(video, u64(len(video)))
    // *** READ SAMPLES ***

    // * Time coordinate system
    timescale := video_atom.moov.traks[0].mdia.mdhd.timescale
    video_duration := video_atom.moov.traks[0].mdia.mdhd.duration / timescale
    // * STTS
    sample_duration := f32(video_atom.moov.traks[0].mdia.minf.stbl.stts.entries[0].sample_delta) / f32(timescale)
    sample_count := int(video_atom.moov.traks[0].mdia.minf.stbl.stts.entries[0].sample_count)

    sample_per_frag := int(min(sample_count, (index+1)*int(time / sample_duration)) % int(time / sample_duration)) == 0 ? int(time / sample_duration) : sample_count % int(time / sample_duration)
    fmt.println("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!", index, sample_per_frag)
    // * Get Sample Index
    sample_min := index * sample_per_frag
    sample_max :=  min(sample_min + sample_per_frag, sample_count)

    // * Get chunk SIDX
    //seg1_atom.sidxs = {}

    // * Get chunk STSC
    // sample_counter := 0
    // chunk_index := 0
    // for i:=0;i<int(video_atom.moov.traks[0].mdia.minf.stbl.stsc.entry_count);i+=1 {
    //     if sample_counter >= semple_index {
    //         chunk_index = i 
    //         break
    //     }
    //     sample_counter += int(video_atom.moov.traks[0].mdia.minf.stbl.stsc.entries[i].samples_per_chunk)
    // }
    // * Get chunk offset STCO
    
    // chunk_offsets := video_atom.moov.traks[0].mdia.minf.stbl.stco.chunks_offsets[sample_min:sample_max]
    // sample_sizes := video_atom.moov.traks[0].mdia.minf.stbl.stsz.entries_sizes[sample_min:sample_max]

    // seg1_atom.mdat.data = {}
    // for i:=0;i<len(chunk_offsets);i+=1 {
    //     data := video[chunk_offsets[i]:chunk_offsets[i] + sample_sizes[i]]
    //     seg1_atom.mdat.data = slice.concatenate([][]byte{seg1_atom.mdat.data,data})
    // }
  
    // count := int(seg1_atom.moof.trafs[0].trun.sample_count)
 
    // * TFHD
    target := index * sample_per_frag
    seg1_atom.moof.trafs[0].tfhd.track_ID =  video_atom.moov.traks[0].tkhd.track_ID
    seg1_atom.moof.trafs[0].tfhd.default_sample_duration = video_atom.moov.traks[0].mdia.minf.stbl.stts.entries[0].sample_delta
    seg1_atom.moof.trafs[0].tfhd.default_sample_size = video_atom.moov.traks[0].mdia.minf.stbl.stsz.entries_sizes[target]
    seg1_atom.moof.trafs[0].tfhd.default_sample_flags = 0x1010000
    // * TFDT
    seg1_atom.moof.trafs[0].tfdt.baseMediaDecodeTime = u32be(int(video_atom.moov.traks[0].mdia.minf.stbl.stts.entries[0].sample_delta) * sample_per_frag * index) 
    // * TRUN
    seg1_atom.moof.trafs[0].trun.sample_count = u32be(sample_per_frag)
    // ? seg1_atom.moof.trafs[0].trun.data_offset = ???
    seg1_atom.moof.trafs[0].trun.first_sample_flags = 0x2000000

    ctt_count := int(video_atom.moov.traks[0].mdia.minf.stbl.ctts.entry_count)
    crawl_offset := 0
    for i:=0;i<ctt_count;i+=1 {
        offset := video_atom.moov.traks[0].mdia.minf.stbl.ctts.entries[i].sample_offset
        count := int(video_atom.moov.traks[0].mdia.minf.stbl.ctts.entries[i].sample_count)
        for j:=crawl_offset;j<crawl_offset+count;j+=1 {
            if j >= target {
                seg1_atom.moof.trafs[0].trun.samples[j%sample_per_frag].sample_composition_time_offset = offset
            }
        }
        crawl_offset += count
        if crawl_offset >= target + sample_per_frag {
            break
        }
    }

    
    new_seg1_b := serialize_mp4(seg1_atom)
    fmt.println(len(new_seg1_b))
    file, err := os.open(fmt.tprintf("./test5/seg-%d.m4s", index), os.O_CREATE)
    if err != os.ERROR_NONE {
        panic("FILE ERROR")
    }
    
    defer os.close(file)
    os.write(file,  new_seg1_b)
}