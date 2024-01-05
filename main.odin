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
	folder := args[0]
	segment_number := strconv.atoi(args[1])
	segment_duration := strconv.atof(args[2])
	size_video := os.file_size_from_path(fmt.tprintf("./%s/test.mp4", folder))
	size_seg := os.file_size_from_path(fmt.tprintf("./%s/save/seg-%d.m4s", folder, segment_number))
	f_vid, f_vid_err := os.open(fmt.tprintf("./%s/test.mp4", folder))
	if f_vid_err != 0 {
		return
	}
	defer os.close(f_vid)
	f_seg, f_seg_err := os.open(fmt.tprintf("./%s/save/seg-%d.m4s", folder, segment_number))
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
	old_seg_box, seg_size := mp4.deserialize_mp4(seg, u64(size_seg))

	// * Input
	//segment_duration: f64 = 6.0 // 3,753750 3.753750
	//segment_duration: f64 =  //3.753750

	segment := mp4.new_segment(&mp4_box, segment_number, segment_duration)


	//log.debugf("segment.segment_count : %v", segment.segment_count)
	//log.debugf("segment.segment_duration : %v", segment.segment_duration)
	//log.debugf("segment.segment_number : %v", segment.segment_number)
	//log.debugf("segment.segment_count : %v", segment.segment_count)
	log.debugf("segment.video_segment_sample_count: %v", segment.video_segment_sample_count)
	log.debugf("segment.video_decoding_times : %v", segment.video_decoding_times)
	log.debugf("segment.video_presentation_time_offsets: %v", segment.video_presentation_time_offsets)
	log.debugf("segment.video_sample_sizes: %v", segment.video_sample_sizes)
	log.debugf("segment.video_default_size: %v", segment.video_default_size)

	// log.debugf("SEGMENT : %v", segment_number)
	// * STYP
	seg_box := mp4.Mp4{}
	//seg_box.styp = old_seg_box.styp
	seg_box.styp = mp4.create_styp(segment)

	// * MOOF
	seg_box.moof = mp4.create_moof(segment)
	//seg_box.moof = old_seg_box.moof
	seg_box.mdat = mp4.create_mdat(segment, vid)
	//seg_box.mdat = old_seg_box.mdat
	// * SIDX
	sidxs := mp4.create_sidxs(segment, seg_box.moof.box.size + seg_box.mdat.box.size)
	//sidxs := old_seg_box.sidxs
	clear(&seg_box.sidxs)
	for sidx in sidxs {
		append(&seg_box.sidxs, sidx)
	}
	new_seg := mp4.serialize_mp4(seg_box)
	handle, err := os.open(fmt.tprintf("./%s/seg-%d.m4s", folder, segment_number), os.O_CREATE)
	fmt.println("%v\n", len(vid))
	defer os.close(handle)
	os.write(handle, new_seg)
}
