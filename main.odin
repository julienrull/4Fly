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

	segment := mp4.new_segment(&mp4_box, segment_number, segment_duration)
	// fmt.println("---")
	// fmt.println("segment_duration", segment.segment_duration)
	// fmt.println("segment_count", segment.segment_count)
	// fmt.println("segment_number", segment.segment_number)

	// fmt.println("segment_video_sample_count", segment.video_segment_sample_count)
	// fmt.println("video_decoding_times", segment.video_decoding_times)
	// fmt.println("video_presentation_time_offsets", segment.video_presentation_time_offsets)
	// fmt.println("video_sample_sizes", segment.video_sample_sizes)

	// fmt.println("segment_sound_sample_count", segment.sound_segment_sample_count)
	// fmt.println("sound_decoding_times", segment.sound_decoding_times)
	// fmt.println("sound_presentation_time_offsets", segment.sound_presentation_time_offsets)
	// fmt.println("sound_sample_sizes", segment.sound_sample_sizes)


	// * STYP
	seg_box.styp = mp4.create_styp(segment)
	// * SIDX
	sidxs := mp4.create_sidxs(segment)
	clear(&seg_box.sidxs)
	for sidx in sidxs {
		append(&seg_box.sidxs, sidx)
	}

	// * MOOF
	seg_box.moof = mp4.create_moof(segment)
	seg_box.mdat = mp4.create_mdat(segment)
	seg_box.sidxs[0].items[0].referenced_size = u32be(
		seg_box.moof.box.size + seg_box.mdat.box.size,
	)
	seg_box.sidxs[1].items[0].referenced_size = u32be(
		seg_box.moof.box.size + seg_box.mdat.box.size,
	)
	new_seg := mp4.serialize_mp4(seg_box)
	handle, err := os.open(fmt.tprintf("test5/seg-%d.m4s", strconv.atoi(args[2])), os.O_CREATE)
	defer os.close(handle)
	os.write(handle, new_seg)
}
