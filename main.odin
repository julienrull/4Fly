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
	segment_duration: f64 = 3.753750 // 3,753750
	segment_number := strconv.atoi(args[2])

	segment := mp4.new_segment(&mp4_box, segment_number, segment_duration)

	// fmt.println("video", segment.video_segment_sample_count)
	// fmt.println("sound", segment.sound_segment_sample_count)

	// trak_shift :=
	// 	(f64(mp4_box.moov.traks[0].tkhd.duration) /
	// 			f64(mp4_box.moov.traks[0].mdia.mdhd.timescale) -
	// 		f64(mp4_box.moov.traks[1].tkhd.duration) /
	// 			f64(mp4_box.moov.traks[1].mdia.mdhd.timescale)) *
	// 	f64(mp4_box.moov.mvhd.timescale)

	// fmt.println("trak_shift", trak_shift)


	// for trak in mp4_box.moov.traks {
	// 	duration: u32be = 0
	// 	timescale := trak.mdia.mdhd.timescale
	// 	for stts in trak.mdia.minf.stbl.stts.entries {
	// 		duration += stts.sample_count * stts.sample_delta
	// 	}
	// 	samp, dur := mp4.get_segment_first_sample(trak, u32be(segment_number), segment_duration)
	// 	chunk, fs := mp4.sample_to_chunk(trak, int(samp))
	// 	// log.debugf("Trak duration:\t%v", f64(duration) / f64(timescale))
	// }
	//mp4.create_mdat(segment)

	// log.debugf("segment.segment_count : %v", segment.segment_count)
	// log.debugf("segment.segment_duration : %v", segment.segment_duration)
	// log.debugf("segment.segment_number : %v", segment.segment_number)
	// log.debugf("segment.video_decoding_times : %v", segment.video_decoding_times)
	// log.debugf("segment.segment_count : %v", segment.segment_count)
	//log.debugf("SEGMENT NUMBER %v", segment.video_presentation_time_offsets)

	// * STYP
	seg_box.styp = mp4.create_styp(segment)

	// * MOOF
	seg_box.moof = mp4.create_moof(segment)
	seg_box.mdat = mp4.create_mdat(segment, vid)
	// * SIDX
	sidxs := mp4.create_sidxs(segment, seg_box.moof.box.size + seg_box.mdat.box.size)
	clear(&seg_box.sidxs)
	for sidx in sidxs {
		append(&seg_box.sidxs, sidx)
	}
	new_seg := mp4.serialize_mp4(seg_box)
	handle, err := os.open(fmt.tprintf("test5/seg-%d.m4s", strconv.atoi(args[2])), os.O_CREATE)
	defer os.close(handle)
	os.write(handle, new_seg)
}
