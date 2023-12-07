package main

import "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strings"
import "core:strconv"
import "core:testing"
import "mp4"

main :: proc() {
	args := os.args[1:]
        size_video := os.file_size_from_path(args[0])
        size_seg := os.file_size_from_path(args[1])
        f_vid, f_vid_err := os.open(args[0])
        if f_vid_err != 0 {
		return
	}
	defer os.close(f_vid)
        f_seg, f_seg_err := os.open(args[1])
        if f_seg_err != 0 {
		return
	}
	defer os.close(f_seg)
        
        vid, vide_mem_err := mem.alloc_bytes((int)(size_video))
        seg, seg_mem_err := mem.alloc_bytes((int)(size_seg))
        defer delete(vid)
        defer delete(seg)
        os.read(f_vid, vid)
        os.read(f_seg, seg)

        //mp4.recreate_seg_1(strconv.atoi(args[2]), vid, seg)
        mp4_box, mp4size := mp4.deserialize_mp4(vid, u64(size_video))
        for trak in mp4_box.moov.traks {
                sample_number := mp4.time_to_sample(trak, 12.2)
                fmt.println(sample_number)
                fmt.println("---")
                fmt.println(mp4.sample_to_chunk(trak, sample_number))

        }
        
        
}

load_mp4 :: proc(src: string) -> mp4.Mp4 {
        size_video := os.file_size_from_path(src)
        f_vid, f_vid_err := os.open(src)
        if f_vid_err != 0 {
                panic("Error: file opening failed")
	}
        defer os.close(f_vid)
        vid, vide_mem_err := mem.alloc_bytes((int)(size_video))
        defer delete(vid)
        mp4_box, mp4size := mp4.deserialize_mp4(vid, u64(size_video))
        return mp4_box
}




@(test)
test_time_to_sample :: proc(t: ^testing.T){
        //testing.expect_value(t, )
}
