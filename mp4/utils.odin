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


	video_timescale: int,

	video_sample_min: int,
	video_sample_max: int,

	sound_sample_min: int,
	sound_sample_max: int,

	video_segment_sample_count: int,
	//video_decoding_times: [dynamic][2]u32be,
	video_decoding_times: []u32be,
	video_presentation_time_offsets: [dynamic]u32be,
	video_sample_sizes: []u32be,
	video_default_size: u32be,

	sound_timescale: int,
	sound_segment_sample_count: int,
	//sound_decoding_times: [dynamic][2]u32be,
	sound_decoding_times: []u32be,
	sound_presentation_time_offsets: [dynamic]u32be,
	sound_sample_sizes: []u32be,
	sound_default_size: u32be,
}


new_segment :: proc(mp4: ^Mp4, segment_number: int, segment_duration: f64) -> (segment: Segment)  {
	segment.mp4 = mp4
	segment.segment_number = segment_number
	segment.segment_duration = segment_duration
	segment_count_f := f64(mp4.moov.mvhd.duration) / f64(mp4.moov.mvhd.timescale) / segment_duration
	segment.segment_count = int(segment_count_f)
	if segment_count_f > f64(segment.segment_count){
		segment.segment_count += 1
	} 

	starting_time := f64(segment_number) * segment_duration
	ending_time := starting_time + segment_duration

	for trak in mp4.moov.traks {
		stts := trak.mdia.minf.stbl.stts
		handler_type := trak.mdia.hdlr.handler_type
		trak_type := to_string(&handler_type)
		time_cum: f64
		sample_count := 0
		decoding_times: [dynamic][2]u32be = make([dynamic][2]u32be, 0, 16)
		sample_cum := 0

		sample_number, _ := get_segment_first_sample(trak, trak.mdia.mdhd.timescale, u32be(segment.segment_number), f64(segment.segment_duration))
		sample_number_next, _ := get_segment_first_sample(trak, trak.mdia.mdhd.timescale, u32be(segment.segment_number + 1), f64(segment.segment_duration))
		//fmt.println("sample_number_prev", sample_number_next)
		//fmt.println("sample_number", sample_number)

		segment_sample_count := int(sample_number_next - sample_number)
		if trak_type == "vide"{
			segment.video_timescale = int(trak.mdia.mdhd.timescale) // 15360
			//segment.video_timescale = 15360 
			//segment.video_timescale =  19200
			//segment.video_timescale = 1820 
			segment.video_segment_sample_count = segment_sample_count
			segment.video_sample_sizes = make([]u32be, segment_sample_count)
			segment.video_decoding_times = make([]u32be, segment_sample_count)
		}else{
			segment.sound_timescale = int(trak.mdia.mdhd.timescale)
			//segment.sound_segment_sample_count = segment_sample_count
			segment.sound_segment_sample_count = segment_sample_count - 1
			segment.sound_sample_sizes = make([]u32be, segment_sample_count)
			segment.sound_decoding_times = make([]u32be, segment_sample_count)
		}
		i := 0
		for sample in int(sample_number)..<int(sample_number_next) {
			if trak_type == "vide" {
				segment.video_decoding_times[i] = get_sample_duration(trak, u32be(sample))
				//segment.video_decoding_times[i] = 600
				if(trak.mdia.minf.stbl.stsz.sample_count > 0) {
					segment.video_sample_sizes[i] = u32be(get_sample_size(trak, u32be(sample)))
				}
				segment.video_default_size = trak.mdia.minf.stbl.stsz.sample_size
				append(&segment.video_presentation_time_offsets, get_sample_presentation_offset(trak, u32be(sample)))
				segment.video_sample_min = int(sample_number)
				segment.video_sample_max = int(sample_number_next)
			}else {
				segment.sound_decoding_times[i] = get_sample_duration(trak, u32be(sample))
				if(trak.mdia.minf.stbl.stsz.sample_count > 0) {
					segment.sound_sample_sizes[i] = u32be(get_sample_size(trak, u32be(sample)))
				}
				segment.sound_default_size = trak.mdia.minf.stbl.stsz.sample_size
				append(&segment.sound_presentation_time_offsets, get_sample_presentation_offset(trak, u32be(sample)))
				segment.sound_sample_min = int(sample_number)
				segment.sound_sample_max = int(sample_number_next)
			}
			i+=1
		}


	}
	//fmt.println(segment)
	return segment
}

get_sample_duration :: proc(trak: Trak, sample_number: u32be) -> (sample_duration: u32be){
	sample_cum: u32be = 1
	for stts in trak.mdia.minf.stbl.stts.entries {
		if sample_cum + stts.sample_count >  sample_number {
			sample_duration = stts.sample_delta
			//fmt.println(sample_duration)
			break
		}
		sample_cum += stts.sample_count
	}
	return sample_duration
}

get_sample_presentation_offset :: proc(trak: Trak, sample_number: u32be) -> (presentation_offset: u32be){
	sample_sum: u32be = 1 
	if(trak.mdia.minf.stbl.ctts.entry_count > 0){
		for ctts in trak.mdia.minf.stbl.ctts.entries {
			if sample_sum + ctts.sample_count >  sample_number {
				presentation_offset = ctts.sample_offset
				break
			}
			sample_sum += ctts.sample_count
		}
	}
	return presentation_offset
}




get_segment_first_sample :: proc(trak: Trak, timescale: u32be, segment_number: u32be, segment_duration_scaled: f64) -> (sample_number: u32be, sample_duration: u32be) {

	// * Variables
	timescale := trak.mdia.mdhd.timescale
	segment_duration := u32be(segment_duration_scaled * f64(timescale))
	segment_begin_time := segment_duration * segment_number
	stts := trak.mdia.minf.stbl.stts
	sample_number = 1
	//fmt.println("segment_number", segment_number)


	// * Get samples decoding times offsets
	for stts in stts.entries {
		// * Variables
		sample_count := stts.sample_count
		sample_duration := stts.sample_delta
		stts_duration := sample_count * sample_duration
		sample_duration_cum: u32be
		// * Find segment range
		if sample_duration_cum + stts_duration >= segment_begin_time {
			target_stts_begin := sample_duration_cum
			target_stts_end := sample_duration_cum + stts_duration
			remain_time_to_begin := segment_begin_time - target_stts_begin
			sample_number_begin := sample_duration_cum + remain_time_to_begin / stts.sample_delta
			sample_number = sample_number_begin + 1
			sample_duration = stts.sample_delta
			return sample_number, sample_duration
		}
		sample_duration_cum += stts_duration
	}


	return sample_number, sample_duration
}



get_segment_presentation_times :: proc(trak: Trak, timescale: u32be, segment_number: u32be, samples_per_segment: u32be, segment_duration:  f64) -> (cts: [dynamic]u32be) {
	log.debugf("segment_number: %v, samples_per_segment: %v, segment_duration: %v", segment_number, samples_per_segment, segment_duration)
	first_sample, first_sample_duation  := get_segment_first_sample(trak, timescale, segment_number,  segment_duration)
	ctts_count := int(trak.mdia.minf.stbl.ctts.entry_count)
	crawl_offset := 0
	cts = make([dynamic]u32be, 0, 16) 
	for i := 0; i < ctts_count; i += 1 {
		ctts := trak.mdia.minf.stbl.ctts.entries[i]
		offset := ctts.sample_offset
		count := int(ctts.sample_count)
		next_crawl_offset := crawl_offset + count
		for j:=crawl_offset; j < next_crawl_offset; j += 1 {
			if crawl_offset > int(first_sample + u32be(samples_per_segment)) {
				break
			}
			if j > int(first_sample) {
				append(&cts, offset)
			}
			crawl_offset += 1
		}
		if crawl_offset > int(first_sample + u32be(samples_per_segment)) {
			break
		}
	}
	return cts
}


sample_to_chunk :: proc(trak: Trak, sample_number: u32be) -> (chunk_number: u32be, first_sample: u32be) {
	stsc := trak.mdia.minf.stbl.stsc
	stsz := trak.mdia.minf.stbl.stsz

	chunk_number = 1
	first_sample = 1
	samples_sum: u32be = 1
	//chunk_sum := 0

	if(int(stsc.entry_count) > 1) {		
		for i := 0; i < int(stsc.entry_count); i += 1 {
			// * Variables
			entry := stsc.entries[i]
			first_chunk := entry.first_chunk
			samples_per_chunk := entry.samples_per_chunk
			sample_desc_index := entry.sample_description_index
			first_sample := samples_sum
			chunk_count: u32be
			if i == int(stsc.entry_count) - 1 {
				chunk_count = 0
			}else {
				chunk_count = stsc.entries[i + 1].first_chunk - first_chunk
			}
			next_first_sample := samples_sum + chunk_count * samples_per_chunk
			// * Entry found
			if next_first_sample > sample_number {
				// * search sub chunk
				for cn in first_chunk..<first_chunk + chunk_count{
					samples_sum_next := samples_sum + samples_per_chunk
					if samples_sum_next > sample_number{
						return cn, samples_sum
					}
					samples_sum = samples_sum_next
				}
			}
			// * MAJ
			samples_sum = next_first_sample
		}

	}
		return chunk_number, first_sample
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





get_chunk_offset :: proc(trak: Trak, chunk_number: u32be) -> u64 {
	stco := trak.mdia.minf.stbl.stco
	co64 := trak.mdia.minf.stbl.co64

	return(
		stco.entry_count > 0 \
		? u64(stco.chunks_offsets[chunk_number - 1]) \
		: u64(co64.chunks_offsets[chunk_number - 1]) \
	)
}

get_sample_size :: proc(trak: Trak, sample_number: u32be) -> (sample_size: u64) {
	stsz := trak.mdia.minf.stbl.stsz
	stz2 := trak.mdia.minf.stbl.stz2
	if stsz.sample_size > 0 {
		sample_size = u64(stsz.sample_size)
	} else {
		if stsz.sample_count > 0 {
			sample_size = u64(stsz.entries_sizes[sample_number - 1])
		} else {
			if stz2.sample_count > 0 {
				samples_per_entry:u32be = 0
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
				sample_size = u64(stz2.entries_sizes[index - 1] << u64(offset))
			}
		}
	}
	return sample_size
}



STYP_TYPE :: 0x73747970
create_styp :: proc(segment: Segment) -> (styp: Ftyp){
	segment.mp4.ftyp.box.type = STYP_TYPE
	return segment.mp4.ftyp
}


get_trak_duration :: proc(trak: Trak, timescale: u32be) -> (duration: f64) {
	for stts in trak.mdia.minf.stbl.stts.entries {
		duration += f64(stts.sample_count) * f64(stts.sample_delta) / f64(timescale)
	}
	return duration 
}

get_traks_shift :: proc(traks: []Trak, trak_timescale_1: u32be, trak_timescale_2: u32be, moov_timescale: u32be) -> u32be {
	sub: f64 = math.abs(get_trak_duration(traks[0], trak_timescale_1) - get_trak_duration(traks[1], trak_timescale_2))
	return len(traks) == 2 ? u32be(sub* f64(moov_timescale))  : 0  
}


create_sidxs :: proc(segment: Segment, referenced_size: u32be) -> []Sidx {
	// * Mp4 info
	mp4_duration := segment.mp4.moov.mvhd.duration // TODO: need version checking
	mp4_timescale := segment.mp4.moov.mvhd.timescale 
	traks := segment.mp4.moov.traks
	trak_count := len(traks)
	sidxs: []Sidx = make([]Sidx, 2)
	vide_trak: Trak
	soun_trak: Trak
	vide_trak_to_sidx: int
	soun_trak_to_sidx: int
	for i := 0; i < trak_count; i += 1 {
		trak := segment.mp4.moov.traks[i]
		handler_type := trak.mdia.hdlr.handler_type
		trak_type := to_string(&traks[i].mdia.hdlr.handler_type)
		sidxs[i].fullbox.box.type = 0x73696478 // * string("sidxs[i]") to u32be
		sidxs[i].fullbox.box.size = 52
		sidxs[i].fullbox.version = 1
		sidxs[i].reference_ID = trak.tkhd.track_ID
		sidxs[i].timescale = to_string(&handler_type) == "vide" ?  u32be(segment.video_timescale)  : u32be(segment.sound_timescale) // 15360 u32be(segment.video_timescale) 
		if trak_type == "vide" {vide_trak = trak; vide_trak_to_sidx = i}
		if trak_type == "soun" {soun_trak = trak; soun_trak_to_sidx = i}
		if sidxs[i].fullbox.version == 1 {
			sidxs[i].first_offset_extends = u64be((trak_count * 52) - (i + 1) * 52)
		} else {
			sidxs[i].first_offset = u32be((trak_count * 52) - (i + 1) * 52)
		}
		sidxs[i].reference_count = 1
		sidxs[i].items = make([]SegmentIndexBoxItems, sidxs[i].reference_count)
	}
	video_duration: int = 0
	for time in segment.video_decoding_times {
		video_duration += int(time)
	}
	sound_duration: int = 0
	for time in segment.sound_decoding_times {
		sound_duration += int(time)
	}
	// // samp, dur := mp4.get_segment_first_sample(trak, u32be(segment_number), segment_duration)
	// chunk, fs := mp4.sample_to_chunk(trak, int(samp))

	
	sidxs[vide_trak_to_sidx].items[0] = {
		    reference_type = 0,
		    referenced_size = referenced_size, // size moof + size mdate 
		    
		    // subsegment_duration = u32be(segment.segment_duration * f64(sidxs[vide_trak_to_sidx].timescale)),
		    subsegment_duration = u32be(video_duration),

		    starts_with_SAP = 1,
		    SAP_type = 0, 
		    SAP_delta_time = 0
	}
	sidxs[soun_trak_to_sidx].items[0] = {
		    reference_type = 0,
		    referenced_size = referenced_size, // size moof + size mdate 
		    // subsegment_duration = u32be(segment.segment_duration * f64(sidxs[soun_trak_to_sidx].timescale)),
		    subsegment_duration = u32be(sound_duration),
		    starts_with_SAP = 1,
		    SAP_type = 0, 
		    SAP_delta_time = 0
	}
	// * EARLIEST_PRESENTATION_TIME
	vide_duration:= get_trak_duration(vide_trak, u32be(segment.video_timescale))
	soun_duration := get_trak_duration(soun_trak, u32be(segment.sound_timescale))
	shift := get_traks_shift([]Trak{vide_trak, soun_trak}, u32be(segment.video_timescale), u32be(segment.sound_timescale), mp4_timescale)
	earliest_presentation_time := segment.video_presentation_time_offsets[0]

	if sidxs[vide_trak_to_sidx].fullbox.version == 1 {
		
		duration_cum := segment.segment_number == 0 ? 0 : u64be(segment.segment_duration * f64(vide_trak.mdia.mdhd.timescale)) * u64be(segment.segment_number) + u64be(segment.video_presentation_time_offsets[0])
		sidxs[vide_trak_to_sidx].earliest_presentation_time_extends = duration_cum + u64be(segment.video_presentation_time_offsets[0])
	} else {
		duration_cum := segment.segment_number == 0 ? 0 : u32be(segment.segment_duration * f64(vide_trak.mdia.mdhd.timescale)) * u32be(segment.segment_number) + segment.video_presentation_time_offsets[0]
		sidxs[vide_trak_to_sidx].earliest_presentation_time = duration_cum + segment.video_presentation_time_offsets[0]
	}


	fmt.println("shift", shift)

	// if vide_duration > soun_duration {
	// 	earliest_presentation_time += shift
	// }else if vide_duration < soun_duration{
	// 	earliest_presentation_time -= shift
	// }

	// if sidxs[soun_trak_to_sidx].fullbox.version == 1 {
	// 	duration_cum := segment.segment_number == 0 ? 0 : u64be(segment.segment_duration * f64(soun_trak.mdia.mdhd.timescale)) * u64be(segment.segment_number) + u64be(segment.video_presentation_time_offsets[0])
	// 		sidxs[soun_trak_to_sidx].earliest_presentation_time_extends = u64be(earliest_presentation_time) + u64be(duration_cum)
	// } else {
	// 	duration_cum := segment.segment_number == 0 ? 0 : u32be(segment.segment_duration * f64(soun_trak.mdia.mdhd.timescale)) * u32be(segment.segment_number) + segment.video_presentation_time_offsets[0]
	// 	sidxs[soun_trak_to_sidx].earliest_presentation_time = earliest_presentation_time + duration_cum
	// }
	// * !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	duration_cum := segment.segment_number == 0 ? 0 : u64be(segment.segment_duration * f64(vide_trak.mdia.mdhd.timescale)) * u64be(segment.segment_number) + u64be(segment.video_presentation_time_offsets[0])
	sidxs[vide_trak_to_sidx].earliest_presentation_time_extends = u64be(duration_cum)
	sidxs[soun_trak_to_sidx].earliest_presentation_time_extends = u64be(duration_cum)
	// * !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


	return sidxs
}

MOOF_TYPE :: 0x6D6F6F66
MFHD_TYPE :: 0x6D666864


create_moof :: proc(segment: Segment) -> (moof: Moof){
	moof.box.type = MOOF_TYPE

	moof.mfhd.fullbox.box.type = MFHD_TYPE
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
			moof.trafs[i].trun.data_offset = i32be(moof.box.size) + 8
		}else {
			moof.trafs[i].trun.data_offset = i32be(moof.box.size) + 8
			prev_trak := segment.mp4.moov.traks[i - 1]
			handler_type := prev_trak.mdia.hdlr.handler_type
			sample_sizes := to_string(&handler_type) == "vide" ? segment.video_sample_sizes : segment.sound_sample_sizes
			sample_size := to_string(&handler_type) == "vide" ? segment.video_default_size : segment.sound_default_size
			sample_count := to_string(&handler_type) == "vide" ? segment.video_segment_sample_count : segment.sound_segment_sample_count
			size_cum :u32be = 0
			if len(sample_sizes) > 0 {
				for s in sample_sizes {
					size_cum += s
				} 
				moof.trafs[i].trun.data_offset += i32be(size_cum)
			}else {
				moof.trafs[i].trun.data_offset = i32be(sample_size * u32be(sample_count))
			}
			
		}
	}
	return moof
}


TRAF_TYPE :: 0x74726166

create_traf :: proc(trak: Trak, segment: Segment) -> (traf: Traf) {
	handler_type := trak.mdia.hdlr.handler_type
	trak_type := to_string(&handler_type)
	traf.box.type = TRAF_TYPE
	tfhd_flags := TFHD_DEFAULT_SAMPLE_DURATION_PRESENT | TFHD_DEFAULT_SAMPLE_SIZE_PRESENT | TFHD_DEFAULT_SAMPLE_FLAGS_PRESENT | TFHD_DEFAULT_BASE_IS_MOOF
	traf.tfhd = create_tfhd(trak, segment, tfhd_flags)
	traf.tfdt = create_tfdt(trak, segment)
	trun_flags := TRUN_DATA_OFFSET_PRESENT | TRUN_SAMPLE_FLAGS_PRESENT
	if trak_type == "vide" {
		trun_flags |= TRUN_FIRST_SAMPLE_FLAGS_PRESENT
	}
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
		
		tfhd.default_sample_duration = trak_type == "vide" ? segment.video_decoding_times[0] : segment.sound_decoding_times[0]
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
		tfhd.default_sample_flags = to_string(&handler_type) == "vide" ? 0x1010000 : 0x2000000 
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
	handler_type := trak.mdia.hdlr.handler_type
	timescale := to_string(&handler_type) == "vide" ?  segment.video_timescale : segment.sound_timescale
	tfdt.fullbox.box.type = TFDT_TYPE
	tfdt.baseMediaDecodeTime_extends = u64be(segment.segment_duration * f64(timescale)) * u64be(segment.segment_number)
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
	handler_type := trak.mdia.hdlr.handler_type
	trun.fullbox.box.type = TRUN_TYPE
	flags := u32be(tr_flags) << 8
	trun.fullbox.flags = (^[3]byte)(&flags)^
	size: int = 12 + size_of(u32be)
	if tr_flags & TRUN_DATA_OFFSET_PRESENT == TRUN_DATA_OFFSET_PRESENT {
		//fmt.println("TRUN_DATA_OFFSET_PRESENT")
		size += size_of(i32be)
	}
	if tr_flags & TRUN_FIRST_SAMPLE_FLAGS_PRESENT == TRUN_FIRST_SAMPLE_FLAGS_PRESENT {
		//fmt.println("TRUN_FIRST_SAMPLE_FLAGS_PRESENT")
		trun.first_sample_flags = to_string(&handler_type) == "vide" ? 0x2000000 : 0
		size += size_of(u32be)
	} 

	sample_count := to_string(&handler_type) == "vide" ?  segment.video_segment_sample_count : segment.sound_segment_sample_count
	decoding_times := to_string(&handler_type) == "vide" ?  segment.video_decoding_times : segment.sound_decoding_times
	trun.sample_count = u32be(sample_count)
	trun.samples = make([]TrackRunBoxSample, trun.sample_count)
	for i:=0;i<sample_count;i+=1 {
		if tr_flags & TRUN_SAMPLE_DURATION_PRESENT == TRUN_SAMPLE_DURATION_PRESENT {
			for time in decoding_times {
					trun.samples[i].sample_duration = time
			}	
			size += size_of(u32be)
		}
		
		if tr_flags & TRUN_SAMPLE_SIZE_PRESENT == TRUN_SAMPLE_SIZE_PRESENT {
			//log.debugf("%v", len(segment.sound_sample_sizes))
			trun.samples[i].sample_size = to_string(&handler_type) == "vide" ? segment.video_sample_sizes[i] : segment.sound_sample_sizes[i] // 16842752 segment.video_sample_sizes[i]
			size += size_of(u32be)
		}
		if tr_flags & TRUN_SAMPLE_COMPOSITION_TIME_OFFSETS_PRESENT == TRUN_SAMPLE_COMPOSITION_TIME_OFFSETS_PRESENT {
			//log.debugf("sample_count : %v", sample_count)
			//log.debugf("len(segment.video_presentation_time_offsets) : %v", len(segment.video_presentation_time_offsets))
			trun.samples[i].sample_composition_time_offset = to_string(&handler_type) == "vide" ? segment.video_presentation_time_offsets[i] : segment.sound_presentation_time_offsets[i]
			size += size_of(u32be)
		}
		if tr_flags & TRUN_SAMPLE_FLAGS_PRESENT == TRUN_SAMPLE_FLAGS_PRESENT {
			// * CONCERNE SAMPLES
			// * sample‐flags‐present:	each	sample	has	its	own	flags,	otherwise	the	default	is	used.
			if i == 0 {
				trun.samples[i].sample_flags = 33554432// 16842752
			}else {
				trun.samples[i].sample_flags = 16842752// 16842752
			}
			size += size_of(u32be)
		}
	}
	trun.fullbox.box.size = u32be(size)
	//fmt.println("len(trun.samples)", len(trun.samples))
	return trun
}

get_sample_offset :: proc(trak: Trak, chunk_offset: u64, first_chunk_sample: u32be, sample_number: u32be) -> (sample_offset: u64, sample_size: u64) {
	sample_offset = chunk_offset
	if trak.mdia.minf.stbl.stsc.entry_count > 1 {
		for sample in first_chunk_sample..=sample_number {
			if(sample == sample_number){
				sample_size = get_sample_size(trak, sample)
			}else{
				sample_offset += get_sample_size(trak, sample)
			}
		}
	}else{
		sample_size = get_sample_size(trak, sample_number)
	}
	return sample_offset, sample_size
}


MDAT_TYPE :: 0x6D646174
create_mdat :: proc(segment: Segment, video_file_b: []byte) -> (mdat: Mdat) {
	mdat.box.type = MDAT_TYPE
	mdat.box.size = 8
	for i := 0; i < len(segment.mp4.moov.traks); i += 1 {
		trak := segment.mp4.moov.traks[i]
		handler_type := trak.mdia.hdlr.handler_type
		timescale := to_string(&handler_type) == "vide" ? u32be(segment.video_timescale) : u32be(segment.sound_timescale)
		first_sample, first_sample_duration := get_segment_first_sample(trak, timescale, u32be(segment.segment_number), segment.segment_duration)
		first_sample_next, first_sample_duration_next := get_segment_first_sample(trak, timescale,u32be(segment.segment_number + 1), segment.segment_duration)
		for sample in first_sample..<first_sample_next {
			chunk_number, first_chunk_sample := sample_to_chunk(trak, sample)
			if trak.mdia.minf.stbl.stsc.entry_count <= 1 {
				chunk_number = sample
			}
			// log.debugf("sample, chunk_number, first_chunk_sample = %v, %v, %v", sample, chunk_number, first_chunk_sample)
			chunk_offset := get_chunk_offset(trak, chunk_number)
			//log.debugf("sample, chunk_number, chunk_offset = %v, %v, %v", sample, chunk_number, chunk_offset)
			sample_offset, sample_size := get_sample_offset(trak, chunk_offset, first_chunk_sample, sample)
			if to_string(&handler_type) == "vide"{
				fmt.println(sample_offset, sample_offset + sample_size)
			} 
			data := video_file_b[sample_offset : sample_offset + sample_size]
			mdat.data = slice.concatenate([][]byte{mdat.data,data})
			mdat.box.size += u32be(sample_size)
		}
	}
	return mdat
}
