package mp4

import "core:fmt"
import "core:log"
import "core:math"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strings"

Segment :: struct {
	mp4: ^Mp4,
	segment_duration: f64,
	segment_count: int,
	segment_number: int,

	video_sample_min: int,
	video_sample_max: int,

	sound_sample_min: int,
	sound_sample_max: int,

	video_segment_sample_count: int,
	video_decoding_times: [dynamic][2]u32be,
	video_presentation_time_offsets: [dynamic]u32be,
	video_sample_sizes: []u32be,
	video_default_size: u32be,

	sound_segment_sample_count: int,
	sound_decoding_times: [dynamic][2]u32be,
	sound_presentation_time_offsets: [dynamic]u32be,
	sound_sample_sizes: []u32be,
	sound_default_size: u32be,
}

new_segment :: proc(mp4: ^Mp4, segment_number: int, segment_duration: f64) -> (segment: Segment)  {
	segment.mp4 = mp4
	segment.segment_number = segment_number
	segment.segment_duration = segment_duration
	segment.segment_count = int(mp4.moov.mvhd.duration / mp4.moov.mvhd.timescale)

	starting_time := f64(segment_number) * segment_duration
	ending_time := starting_time + segment_duration



	for trak in mp4.moov.traks {
		stts := trak.mdia.minf.stbl.stts
		time_cum: f64
		sample_count := 0
		decoding_times: [dynamic][2]u32be = make([dynamic][2]u32be, 0, 16)
		sample_cum := 0

		// * STTS sample count and decoding times
		for i:=0;i<int(stts.entry_count);i+=1 {
			entry := stts.entries[i]
			time := f64(entry.sample_delta) * f64(entry.sample_count) / f64(trak.mdia.mdhd.timescale)
			if time_cum + time >= starting_time {
				if(time_cum + time <= ending_time) {
					sample_count += int(entry.sample_count)
					append(&decoding_times, [2]u32be{entry.sample_count, entry.sample_delta})
				}else {
					new_time_cum := time_cum > 0 ? time_cum : starting_time 
					remain := int((ending_time - new_time_cum) / (f64(entry.sample_delta) / f64(trak.mdia.mdhd.timescale)))
					sample_count += remain
					append(&decoding_times, [2]u32be{u32be(remain), entry.sample_delta})
					sample_cum += time_cum > 0 ? sample_count : sample_count * (segment_number + 1)
					//fmt.println("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!", sample_cum)
					break
				}
			}
			time_cum += f64(entry.sample_delta) * f64(entry.sample_count) / f64(trak.mdia.mdhd.timescale)
			sample_cum += int(entry.sample_count)
		}
		//* STSZ Get segment sample sizes
		end_sample_index :=  sample_cum
		start_sample_index := end_sample_index - sample_count
		fmt.println("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!", end_sample_index - start_sample_index)
		// * CTTS samples presentation times
		presentation_time_offsets: [dynamic]u32be
		ctts := trak.mdia.minf.stbl.ctts
		if ctts.entry_count > 0 {
			presentation_time_offsets = get_segment_presentation_times(trak, segment_number, sample_count)
		}

		handler_type := trak.mdia.hdlr.handler_type
		if to_string(&handler_type) == "vide"{
			segment.video_sample_min = start_sample_index
			segment.video_sample_max = end_sample_index
			segment.video_segment_sample_count = sample_count
			segment.video_decoding_times = decoding_times
			segment.video_presentation_time_offsets = presentation_time_offsets
			if trak.mdia.minf.stbl.stsz.sample_count > 0 {
				segment.video_sample_sizes = trak.mdia.minf.stbl.stsz.entries_sizes[start_sample_index:end_sample_index]
			}else if trak.mdia.minf.stbl.stsz.sample_size != 0 {
				segment.video_default_size = trak.mdia.minf.stbl.stsz.sample_size
			}else {
				// stz2 case
			}
		}else if to_string(&handler_type) == "soun"{
			segment.sound_sample_min = start_sample_index
			segment.sound_sample_max = end_sample_index
			segment.sound_segment_sample_count = sample_count
			segment.sound_decoding_times = decoding_times
			segment.sound_presentation_time_offsets = presentation_time_offsets
			
			if trak.mdia.minf.stbl.stsz.sample_count > 0 {
				segment.sound_sample_sizes = trak.mdia.minf.stbl.stsz.entries_sizes[start_sample_index:end_sample_index]
			}else if trak.mdia.minf.stbl.stsz.sample_size != 0 {
				segment.sound_default_size = trak.mdia.minf.stbl.stsz.sample_size
			}else {
				// stz2 case
			}
		}
	}
	return segment
}

get_segment_presentation_times :: proc(trak: Trak, segment_number: int, samples_per_segment: int) -> (cts: [dynamic]u32be) {
	target := segment_number * samples_per_segment
	ctts_count := int(trak.mdia.minf.stbl.ctts.entry_count)
	crawl_offset := 0
	cts = make([dynamic]u32be, 0, 16) 
	for i := 0; i < ctts_count; i += 1 {
		ctts := trak.mdia.minf.stbl.ctts.entries[i]
		offset := ctts.sample_offset
		count := int(ctts.sample_count)
		next_crawl_offset := crawl_offset + count
		for j:=crawl_offset; j < next_crawl_offset; j += 1 {
			if crawl_offset >= target + samples_per_segment {
				break
			}
			if j >= target {
				append(&cts, offset)
			}
			crawl_offset += 1
		}
		if crawl_offset >= target + samples_per_segment {
			break
		}
	}
	return cts
}




to_string :: proc(value: ^u32be) -> string {
	value_b := (^byte)(value)
	str := strings.string_from_ptr(value_b, size_of(u32be))
	return str
}

print_mp4_level :: proc(name: string, level: int) {
	str := ""
	err: mem.Allocator_Error
	i := 0
	for i < level - 1 {
		a := [?]string{str, "-"}
		str, err = strings.concatenate(a[:])
		i = i + 1
	}
	a := [?]string{str, name}
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
		} else {
			offset = size
		}
	}
	return offset
}


get_segment_offsets :: proc(
	mp4: Mp4,
	trak_id: int,
	seg_index: int,
	sample_per_frag: int,
) -> (
	ctts_entries: []u32be,
) {
	ctts_entries = make([]u32be, sample_per_frag)
	target := seg_index * sample_per_frag
	ctt_count := int(mp4.moov.traks[trak_id - 1].mdia.minf.stbl.ctts.entry_count)
	crawl_offset := 0
	for i := 0; i < ctt_count; i += 1 {
		offset := mp4.moov.traks[trak_id - 1].mdia.minf.stbl.ctts.entries[i].sample_offset
		count := int(mp4.moov.traks[trak_id - 1].mdia.minf.stbl.ctts.entries[i].sample_count)
		for j := crawl_offset; j < crawl_offset + count; j += 1 {
			if j >= target {
				ctts_entries[j % sample_per_frag] = offset
			}
		}
		crawl_offset += count
		if crawl_offset >= target + sample_per_frag {
			break
		}
	}
	return ctts_entries
}


time_to_sample :: proc(trak: Trak, time: f64) -> (sample_number: int) {
	trak_timescale := trak.mdia.mdhd.timescale
	stts := trak.mdia.minf.stbl.stts
	sample_duration_sum: f64
	sample_count_sum: int
	for stts_entry in stts.entries {
		grap_value := f64(stts_entry.sample_count * stts_entry.sample_delta / trak_timescale)
		grap_count := stts_entry.sample_count
		if (sample_duration_sum + grap_value >= time) {
			remain := int((time - sample_duration_sum) * f64(trak_timescale))
			return sample_count_sum + remain / int(stts_entry.sample_delta)
		} else {
			sample_duration_sum += grap_value
			sample_count_sum += int(grap_count)
		}
	}
	return 0
}

sample_to_chunk :: proc(trak: Trak, sample_number: int) -> (chunk_number: int, first_sample: int) {
	stsc := trak.mdia.minf.stbl.stsc
	stsz := trak.mdia.minf.stbl.stsz

	samples_sum := 0
	chunk_sum := 0
	for i := 0; i < int(stsc.entry_count); i += 1 {
		// * Get chunk info
		entry := stsc.entries[i]
		first_sample := samples_sum + 1
		chunk_count :=
			i == len(stsc.entries) - 1 \
			? 1 \
			: int(stsc.entries[i + 1].first_chunk - entry.first_chunk)
		sample_count := int(entry.samples_per_chunk) * chunk_count
		// * Check bound
		if sample_number < first_sample + int(sample_count) {
			fmt.println(
				"sample_number",
				sample_number,
				"first_sample",
				first_sample,
				"sample_count",
				sample_count,
			)
			for j := 0; j < int(chunk_count); j += 1 {
				if sample_number < first_sample + int(entry.samples_per_chunk) {
					chunk_number = int(entry.first_chunk) + j
					if chunk_count > 1 {
						chunk_number = int(entry.first_chunk) + j - 1
					}
					return chunk_number, first_sample
				}
				samples_sum += int(entry.samples_per_chunk)
				first_sample = samples_sum + 1
				//chunk_sum += 1
			}
		}
		// *
		samples_sum += int(sample_count)
		chunk_sum += int(chunk_count)
	}

	return chunk_number, first_sample
}

get_chunk_offset :: proc(trak: Trak, chunk_number: int) -> u64 {
	stco := trak.mdia.minf.stbl.stco
	co64 := trak.mdia.minf.stbl.co64

	return(
		stco.entry_count > 0 \
		? u64(stco.chunks_offsets[chunk_number]) \
		: u64(co64.chunks_offsets[chunk_number]) \
	)
}

get_sample_size :: proc(trak: Trak, sample_number: int) -> (sample_size: u64) {
	stsz := trak.mdia.minf.stbl.stsz
	stz2 := trak.mdia.minf.stbl.stz2
	if stsz.sample_size > 0 {
		sample_size = u64(stsz.sample_size)
	} else {
		if stsz.sample_count > 0 {
			sample_size = u64(stsz.entries_sizes[sample_number])
		} else {
			if stz2.sample_count > 0 {
				samples_per_entry := 0
				switch stz2.field_size {
				case 4:
					samples_per_entry = 8
				case 8:
					samples_per_entry = 4
				case 16:
					samples_per_entry = 2
				}
				index := sample_number / samples_per_entry
				offset := ((sample_number % samples_per_entry) - 1) * samples_per_entry
				sample_size = u64(stz2.entries_sizes[index] << u64(offset))
			}
		}
	}
	return sample_size
}

get_sample_offset :: proc(trak: Trak, time: f64) -> u64 {
	sample_number := time_to_sample(trak, time)
	chunk_number, first_sample := sample_to_chunk(trak, sample_number)
	chunk_index := chunk_number > 0 ? chunk_number : sample_number
	chunk_offset := get_chunk_offset(trak, chunk_index)
	offset_size: u64 = 0
	if chunk_number > 0 {
		for i := 0; i < sample_number - first_sample; i += 1 {
			offset_size += get_sample_size(trak, first_sample + i)
		}
	}
	fmt.println(trak.mdia.minf.stbl.stss)
	log.infof(
		"sample_number %d of chunk %d with %d bytes offset in trak %d has an offset of %d bytes.",
		sample_number,
		chunk_index,
		chunk_offset,
		trak.tkhd.track_ID,
		chunk_offset + offset_size,
	)
	return chunk_offset + offset_size
}

get_composition_offset :: proc(trak: Trak, sample_number: int) -> u64 {
	ctts := trak.mdia.minf.stbl.ctts
	ctts_count := int(ctts.entry_count)
	if ctts_count > 0 {
		crawl_offset := 0
		for i := 0; i < ctts_count; i += 1 {
			offset := ctts.entries[i].sample_offset
			count := int(ctts.entries[i].sample_count)
			for j := crawl_offset; j < crawl_offset + count; j += 1 {
				if j >= sample_number {
					return u64(offset)
				}
			}
		}
	}
	return 0
}
STYP_TYPE :: 0x73747970
create_styp :: proc(segment: Segment) -> (styp: Ftyp){
	segment.mp4.ftyp.box.type = STYP_TYPE
	fmt.println(to_string(&segment.mp4.ftyp.box.type))
	return segment.mp4.ftyp
}


create_sidxs :: proc(segment: Segment) -> []Sidx {
	// * Mp4 info
	mp4_duration := segment.mp4.moov.mvhd.duration // TODO: need version checking
	mp4_timescale := segment.mp4.moov.mvhd.timescale
	traks := segment.mp4.moov.traks
	trak_count := len(traks)
	sidxs: []Sidx = make([]Sidx, 2)



	for i := 0; i < trak_count; i += 1 {
		// * FLAGS
		has_duration := false
		has_size := false
		dafault_sample_flags := 0
		tfhd_flags := 0
		trun_flags := 0

		// * Fragment info
		trak := traks[i]
		trak_id := trak.tkhd.track_ID
		trak_timescale := trak.mdia.mdhd.timescale
		trak_type := to_string(&traks[i].mdia.hdlr.handler_type)
		// * styp
		// * sidx
		handler_type := trak.mdia.hdlr.handler_type

		sidxs[i].fullbox.box.type = 0x73696478 // * string("sidxs[i]") to u32be
		sidxs[i].fullbox.box.size = 52
		//sidxs[i].fullbox.box.
		sidxs[i].fullbox.version = 1
		sidxs[i].reference_ID = trak_id
		sidxs[i].timescale = trak_timescale
		if trak_id == 1 {
			sidxs[i].earliest_presentation_time_extends = to_string(&handler_type) == "vide" ? u64be(segment.video_presentation_time_offsets[0]) : u64be(segment.video_presentation_time_offsets[0])
			sidxs[i].first_offset_extends = i == 0 ? u64be(sidxs[i].fullbox.box.size) : 0
		} else {
			sidxs[i].earliest_presentation_time = to_string(&handler_type) == "vide" ? segment.video_presentation_time_offsets[0] : segment.video_presentation_time_offsets[0]
			sidxs[i].first_offset = i == 0 ? u32be(sidxs[i].fullbox.box.size) : 0
		}
		sidxs[i].reference_count = 1
		sidxs[i].items = make([]SegmentIndexBoxItems, sidxs[i].reference_count)
		sidxs[i].items[0] = {
			    reference_type = 0,
			    referenced_size = 1618842, // size moof + size mdate 
			    //subsegment_duration = trak_type == "vide" ? u32be(segment.segment_duration) * trak_timescale: 0,
			    subsegment_duration = u32be(segment.segment_duration * f64(trak_timescale)),
			    starts_with_SAP = 1,
			    SAP_type = 0, 
			    SAP_delta_time = 0
		}
	}

	return sidxs
}

MOOF_TYPE :: 0x6D6F6F66
MFHD_TYPE :: 0x6D666864


create_moof :: proc(segment: Segment) -> (moof: Moof){
	moof.box.type = MOOF_TYPE

	moof.mfhd.fullbox.box.type = MFHD_TYPE
	fmt.println("MFHD_TYPE", to_string(&moof.mfhd.fullbox.box.type))
	moof.mfhd.fullbox.box.size = 16
	moof.box.size = 8 + moof.mfhd.fullbox.box.size
	moof.mfhd.sequence_number = u32be(segment.segment_number) + 1
	for i := 0; i < len(segment.mp4.moov.traks); i += 1 {
		traf := create_traf(segment.mp4.moov.traks[i], segment)
		append(&moof.trafs, traf)
		moof.box.size += traf.box.size
	}

	for i := 0; i < len(segment.mp4.moov.traks); i += 1 {
		trak := segment.mp4.moov.traks[i]
		handler_type := trak.mdia.hdlr.handler_type
		
		if i == 0 {
			moof.trafs[i].trun.data_offset = i32be(moof.box.size)
		}else {
			moof.trafs[i].trun.data_offset = i32be(moof.box.size) + 8
			prev_trak := segment.mp4.moov.traks[i - 1]
			sample_sizes := to_string(&handler_type) == "vide" ? segment.video_sample_sizes : segment.sound_sample_sizes
			sample_size := to_string(&handler_type) == "vide" ? segment.video_default_size : segment.sound_default_size
			sample_count := to_string(&handler_type) == "vide" ? segment.video_segment_sample_count : segment.sound_segment_sample_count
			size_cum :u32be = 0
			if len(sample_sizes) > 0 {
				for s in sample_sizes {
					size_cum += s
				}
				moof.trafs[i].trun.data_offset = i32be(size_cum)
			}else {
				moof.trafs[i].trun.data_offset = i32be(sample_size * u32be(sample_count))
			}
			
		}
	}
	fmt.println("WE MA SMOOTH", moof.box.size)
	return moof
}


TRAF_TYPE :: 0x74726166

create_traf :: proc(trak: Trak, segment: Segment) -> (traf: Traf) {
	traf.box.type = TRAF_TYPE
	tfhd_flags := TFHD_DEFAULT_SAMPLE_DURATION_PRESENT | TFHD_DEFAULT_SAMPLE_SIZE_PRESENT | TFHD_DEFAULT_SAMPLE_FLAGS_PRESENT | TFHD_DEFAULT_BASE_IS_MOOF
	traf.tfhd = create_tfhd(trak, segment, tfhd_flags)
	traf.tfdt = create_tfdt(trak, segment)
	trun_flags := TRUN_DATA_OFFSET_PRESENT | TRUN_FIRST_SAMPLE_FLAGS_PRESENT
	handler_type := trak.mdia.hdlr.handler_type
	trak_type := to_string(&handler_type)
	if trak.mdia.minf.stbl.stts.entry_count > 1 {
		trun_flags |= TRUN_SAMPLE_DURATION_PRESENT
	}
	sample_sizes := trak_type == "vide" ? segment.video_sample_sizes : segment.sound_sample_sizes 
	if len(sample_sizes) > 0 {
		trun_flags |= TRUN_SAMPLE_SIZE_PRESENT
		//fmt.println("SAMPLE SIZE PRESENT", sample_sizes)
	}
	if trak.mdia.minf.stbl.ctts.entry_count > 0 {
		trun_flags |= TRUN_SAMPLE_COMPOSITION_TIME_OFFSETS_PRESENT
	}
	traf.trun = create_trun(trak, segment, trun_flags)
	traf.box.size = 8
	traf.box.size += traf.tfhd.fullbox.box.size + traf.tfdt.fullbox.box.size + traf.trun.fullbox.box.size
	
	return traf
}


TFHD_TYPE :: 0x74666864
// * trun flags
TFHD_BASE_DATA_OFFSET_PRESENT 			:: 0x000001 // ???
TFHD_SAMPLE_DESCRIPTION_INDEX_PRESENT 	:: 0x000002 // ???
TFHD_DEFAULT_SAMPLE_DURATION_PRESENT 	:: 0x000008
TFHD_DEFAULT_SAMPLE_SIZE_PRESENT 		:: 0x000010
TFHD_DEFAULT_SAMPLE_FLAGS_PRESENT 		:: 0x000020
TFHD_DURATION_IS_EMPTY 					:: 0x010000 // ???
TFHD_DEFAULT_BASE_IS_MOOF 				:: 0x020000


create_tfhd :: proc(trak: Trak, segment: Segment, tf_flags: int) -> (tfhd: Tfhd) {
	tfhd.fullbox.box.type = TFHD_TYPE
	tfhd.fullbox.version = 0
	handler_type := trak.mdia.hdlr.handler_type
	trak_type := to_string(&handler_type)
	flags := u32be(tf_flags) << 8
	tfhd.fullbox.flags = (^[3]byte)(&flags)^
	tfhd.track_ID = trak.tkhd.track_ID
	size: int  = 12
	if tf_flags & TFHD_BASE_DATA_OFFSET_PRESENT == TFHD_BASE_DATA_OFFSET_PRESENT {
		size += size_of(u64be)
	}
	if tf_flags & TFHD_SAMPLE_DESCRIPTION_INDEX_PRESENT == TFHD_SAMPLE_DESCRIPTION_INDEX_PRESENT {
		size += size_of(u32be)
	}
	if tf_flags & TFHD_DEFAULT_SAMPLE_DURATION_PRESENT == TFHD_DEFAULT_SAMPLE_DURATION_PRESENT {
		
		tfhd.default_sample_duration = trak_type == "vide" ? segment.video_decoding_times[0][1] : segment.sound_decoding_times[0][1]
		size += size_of(u32be)
	}
	if tf_flags & TFHD_DEFAULT_SAMPLE_SIZE_PRESENT == TFHD_DEFAULT_SAMPLE_SIZE_PRESENT {
		if trak_type == "vide" {
			if len(segment.video_sample_sizes) > 0 {
				tfhd.default_sample_size = segment.video_sample_sizes[0]
			}else{
				tfhd.default_sample_size = segment.video_default_size
			}
		}else {
			if len(segment.sound_sample_sizes) > 0 {
				tfhd.default_sample_size = segment.sound_sample_sizes[0]
			}else{
				tfhd.default_sample_size = segment.sound_default_size
			}
		}
		size += size_of(u32be)
	}
	if tf_flags & TFHD_DEFAULT_SAMPLE_FLAGS_PRESENT == TFHD_DEFAULT_SAMPLE_FLAGS_PRESENT {
		size += size_of(u32be)
	}
	if tf_flags & TFHD_DURATION_IS_EMPTY == TFHD_DURATION_IS_EMPTY {
		
		size += size_of(u32be)
	}
	if tf_flags & TFHD_DEFAULT_BASE_IS_MOOF == TFHD_DEFAULT_BASE_IS_MOOF {
		size += size_of(u32be)
	}
	tfhd.fullbox.box.size = u32be(size)
	return tfhd
}

TFDT_TYPE :: 0x74666474

create_tfdt :: proc(trak: Trak, segment: Segment) -> (tfdt: Tfdt) {
	tfdt.fullbox.box.type = TFDT_TYPE
	tfdt.baseMediaDecodeTime_extends = u64be(segment.segment_duration * f64(trak.mdia.mdhd.timescale))
	tfdt.fullbox.version = 1
	tfdt.fullbox.box.size = 20
	return tfdt
}

TRUN_TYPE :: 0x7472756E
// * trun flags
TRUN_DATA_OFFSET_PRESENT	:: 0x000001
TRUN_FIRST_SAMPLE_FLAGS_PRESENT:: 0x000004
TRUN_SAMPLE_DURATION_PRESENT:: 0x000100
TRUN_SAMPLE_SIZE_PRESENT:: 0x000200
TRUN_SAMPLE_FLAGS_PRESENT:: 0x000400
TRUN_SAMPLE_COMPOSITION_TIME_OFFSETS_PRESENT:: 0x000800

create_trun :: proc(trak: Trak, segment: Segment, tr_flags: int) -> (trun: Trun) {
	trun.fullbox.box.type = TRUN_TYPE
	flags := u32be(tr_flags) << 8
	trun.fullbox.flags = (^[3]byte)(&flags)^
	size: int = 12 + size_of(u32be)
	if tr_flags & TRUN_DATA_OFFSET_PRESENT == TRUN_DATA_OFFSET_PRESENT {
		fmt.println("TRUN_DATA_OFFSET_PRESENT")
		size += size_of(i32be)
	}
	if tr_flags & TRUN_FIRST_SAMPLE_FLAGS_PRESENT == TRUN_FIRST_SAMPLE_FLAGS_PRESENT {
		fmt.println("TRUN_FIRST_SAMPLE_FLAGS_PRESENT")
		size += size_of(u32be)
	}

	handler_type := trak.mdia.hdlr.handler_type
	sample_count := to_string(&handler_type) == "vide" ?  segment.video_segment_sample_count : segment.sound_segment_sample_count
	trun.sample_count = u32be(sample_count)
	trun.samples = make([]TrackRunBoxSample, trun.sample_count)
	for i:=0;i<sample_count;i+=1 {
		if tr_flags & TRUN_SAMPLE_DURATION_PRESENT == TRUN_SAMPLE_DURATION_PRESENT {
			decoding_times := to_string(&handler_type) == "vide" ? segment.video_decoding_times : segment.sound_decoding_times
			cumul := 0
			for time_map in decoding_times {
				cumul += int(time_map[0])
				if i < cumul {
					trun.samples[i].sample_duration = time_map[1]
					break
				}
				
			}
			size += size_of(u32be)
		}
		if tr_flags & TRUN_SAMPLE_SIZE_PRESENT == TRUN_SAMPLE_SIZE_PRESENT {
			trun.samples[i].sample_size = to_string(&handler_type) == "vide" ? segment.video_sample_sizes[i] : segment.sound_sample_sizes[i]
			size += size_of(u32be)
		}
		if tr_flags & TRUN_SAMPLE_COMPOSITION_TIME_OFFSETS_PRESENT == TRUN_SAMPLE_COMPOSITION_TIME_OFFSETS_PRESENT {
			trun.samples[i].sample_composition_time_offset = to_string(&handler_type) == "vide" ? segment.video_presentation_time_offsets[i] : segment.sound_presentation_time_offsets[i]
			size += size_of(u32be)
		}
		if tr_flags & TRUN_SAMPLE_FLAGS_PRESENT == TRUN_SAMPLE_FLAGS_PRESENT {
			// * CONCERNE SAMPLES
			// * sample‐flags‐present:	each	sample	has	its	own	flags,	otherwise	the	default	is	used.
			size += size_of(u32be)
		}
	}
	trun.fullbox.box.size = u32be(size)
	//fmt.println("len(trun.samples)", len(trun.samples))
	return trun
}

MDAT_TYPE :: 0x6D646174
create_mdat :: proc(segment: Segment) -> (mdat: Mdat) {
	mdat.box.type = MDAT_TYPE
	mdat.box.size = 8
	mdat.data = {}
	
	for i := 0; i < len(segment.mp4.moov.traks); i += 1 {
		trak := segment.mp4.moov.traks[i]
		// * Get chunk STSC
		sample_counter := 0
		chunk_index := 0
		stsc := trak.mdia.minf.stbl.stsc
		for i:=0;i<int(stsc.entry_count);i+=1 {
		    if sample_counter >= segment.segment_number {
		        chunk_index = i 
		        break
		    }
		    sample_counter += int(stsc.entries[i].samples_per_chunk)
		}
		// * Get chunk offset STCO
		handler_type := trak.mdia.hdlr.handler_type
		min := to_string(&handler_type) == "vide" ? segment.video_sample_min : segment.sound_sample_min
		max := to_string(&handler_type) == "vide" ? segment.video_sample_max : segment.sound_sample_max

		chunk_offsets := trak.mdia.minf.stbl.stco.chunks_offsets[min:max]
		sample_sizes := trak.mdia.minf.stbl.stsz.entries_sizes[min:max]

		
		for i:=0;i<len(chunk_offsets);i+=1 {
		    data := segment.mp4.mdat.data[chunk_offsets[i]:chunk_offsets[i] + sample_sizes[i]]
		    mdat.data = slice.concatenate([][]byte{mdat.data,data})
		}
	}
	mdat.box.size += u32be(len(mdat.data))
	return mdat
}


recreate_seg_1 :: proc(index: int, video: []byte, seg1: []byte) {
	fmt.println(len(seg1))
	time: f32 = 3.753750 // 3,753750
	seg1_atom, seg1_atom_size := deserialize_mp4(seg1, u64(len(seg1)))
	video_atom, video_atom_size := deserialize_mp4(video, u64(len(video)))
	// *** READ SAMPLES ***

	// * Time coordinate system
	timescale := video_atom.moov.traks[0].mdia.mdhd.timescale
	video_duration := video_atom.moov.traks[0].mdia.mdhd.duration / timescale
	// * STTS
	sample_duration :=
		f32(video_atom.moov.traks[0].mdia.minf.stbl.stts.entries[0].sample_delta) / f32(timescale)
	sample_count := int(video_atom.moov.traks[0].mdia.minf.stbl.stts.entries[0].sample_count)

	sample_per_frag :=
		int(
			min(sample_count, (index + 1) * int(time / sample_duration)) %
			int(time / sample_duration),
		) ==
		0 \
		? int(time / sample_duration) \
		: sample_count % int(time / sample_duration)
	fmt.println("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!", index, sample_per_frag)
	// * Get Sample Index
	sample_min := index * sample_per_frag
	sample_max := min(sample_min + sample_per_frag, sample_count)

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
	seg1_atom.moof.trafs[0].tfhd.track_ID = video_atom.moov.traks[0].tkhd.track_ID
	seg1_atom.moof.trafs[0].tfhd.default_sample_duration =
		video_atom.moov.traks[0].mdia.minf.stbl.stts.entries[0].sample_delta
	seg1_atom.moof.trafs[0].tfhd.default_sample_size =
		video_atom.moov.traks[0].mdia.minf.stbl.stsz.entries_sizes[target]
	seg1_atom.moof.trafs[0].tfhd.default_sample_flags = 0x1010000
	// * TFDT
	seg1_atom.moof.trafs[0].tfdt.baseMediaDecodeTime = u32be(
		int(video_atom.moov.traks[0].mdia.minf.stbl.stts.entries[0].sample_delta) *
		sample_per_frag *
		index,
	)
	// * TRUN
	seg1_atom.moof.trafs[0].trun.sample_count = u32be(sample_per_frag)
	// ? seg1_atom.moof.trafs[0].trun.data_offset = ???
	seg1_atom.moof.trafs[0].trun.first_sample_flags = 0x2000000

	ctt_count := int(video_atom.moov.traks[0].mdia.minf.stbl.ctts.entry_count)
	crawl_offset := 0
	for i := 0; i < ctt_count; i += 1 {
		offset := video_atom.moov.traks[0].mdia.minf.stbl.ctts.entries[i].sample_offset
		count := int(video_atom.moov.traks[0].mdia.minf.stbl.ctts.entries[i].sample_count)
		for j := crawl_offset; j < crawl_offset + count; j += 1 {
			if j >= target {
				seg1_atom.moof.trafs[0].trun.samples[j % sample_per_frag].sample_composition_time_offset =
					offset
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
	os.write(file, new_seg1_b)
}
