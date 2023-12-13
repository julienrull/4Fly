package main

import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:testing"
import "mp4"


main :: proc() {
	context.logger = log.create_console_logger()
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
	mp4_box, mp4_size := mp4.deserialize_mp4(vid, u64(size_video))
	seg_box, seg_size := mp4.deserialize_mp4(seg, u64(size_seg))

	// * Input
	segment_duration: f64 = 3.753750
	segment_number := strconv.atoi(args[2])
	input := mp4.Input {
		mp4                        = &mp4_box,
		segment_duration           = segment_duration,
		segment_number             = segment_number,
		segment_count              = int(
			f64(mp4_box.moov.mvhd.duration) / f64(mp4_box.moov.mvhd.timescale) / segment_duration,
		),
		segment_video_sample_count = mp4.get_segment_sample_count(
			mp4_box.moov.traks[0],
			segment_number,
			segment_duration,
		),
		segment_sound_sample_count = mp4.get_segment_sample_count(
			mp4_box.moov.traks[1],
			segment_number,
			segment_duration,
		),
	}

	fmt.println("---")
	fmt.println("segment_duration", input.segment_duration)
	fmt.println("segment_count", input.segment_count)
	fmt.println("segment_number", input.segment_number)
	fmt.println("segment_video_sample_count", input.segment_video_sample_count)
	fmt.println("segment_sound_sample_count", input.segment_sound_sample_count)


	// // * STYP
	// seg_box.styp = mp4.create_styp(mp4_box)
	// // * SIDX
	// sidxs := mp4.create_sidxs(mp4_box, strconv.atoi(args[2]), 3.753750)
	// clear(&seg_box.sidxs)
	// for sidx in sidxs {
	// 	append(&seg_box.sidxs, sidx)
	// }

	// // * MOOF
	// // * MFHD
	// seg_box.moof.mfhd.sequence_number = u32be(strconv.atoi(args[2]) + 1)

	// new_seg := mp4.serialize_mp4(seg_box)
	// handle, err := os.open(fmt.tprintf("test5/seg-%d.m4s", strconv.atoi(args[2])), os.O_CREATE)
	// defer os.close(handle)
	// os.write(handle, new_seg)
}
