package mp4

import "core:fmt"
import "core:log"
import "core:math"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strings"

Input :: struct {
	mp4: ^Mp4,
	segment_duration: f64,
	segment_count: int,
	segment_number: int,
	segment_video_sample_count: int,
	// video_decoding_times: []u32be,
	// video_presentation_time_offsets: []u32be,

	segment_sound_sample_count: int,
	// sound_decoding_times: []u32be,
	// sound_presentation_time_offsets: []u32be
}

get_segment_sample_count :: proc(trak: Trak, segment_number: int, segment_duration: f64) -> int  {
	starting_time := f64(segment_number) * segment_duration
	ending_time := starting_time + segment_duration
	stts := trak.mdia.minf.stbl.stts
	time_cum: f64
	sample_count := 0 
	for i:=0;i<int(stts.entry_count);i+=1 {
		entry := stts.entries[i]
		time := f64(entry.sample_delta) * f64(entry.sample_count) / f64(trak.mdia.mdhd.timescale)
		if time_cum + time >= starting_time {
			if(time_cum + time <= ending_time) {
				sample_count += int(entry.sample_count)
			}else {
				fmt.println("TOG")
				remain_to_end: f64
				time_cum = time_cum == 0 ? starting_time : time_cum
				sample_count += int((ending_time - time_cum) / (f64(entry.sample_delta) / f64(trak.mdia.mdhd.timescale)))
				break
				// for remain_to_end < ending_time {
				// 	sample_count += 1
				// 	remain_to_end += f64(entry.sample_delta) / f64(trak.mdia.mdhd.timescale)
				// }
			}
		}
		time_cum += f64(entry.sample_delta) * f64(entry.sample_count) / f64(trak.mdia.mdhd.timescale)
	}
	return sample_count
}

create_input :: proc(mp4: ^Mp4, segment_number: int, segment_duration: f64) -> (input: Input) {
	input.mp4 = mp4
	input.segment_number = segment_number
	input.segment_duration = segment_duration
	input.segment_count = int(mp4.moov.mvhd.duration / mp4.moov.mvhd.timescale)
	input.segment_video_sample_count = 0
	// * parcourir stts 
	return input
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

create_styp :: proc(input: Input) -> (styp: Ftyp){
	return input.mp4.ftyp
}


create_sidxs :: proc(input: Input) -> []Sidx {
	// * Mp4 info
	mp4_duration := input.mp4.moov.mvhd.duration // TODO: need version checking
	mp4_timescale := input.mp4.moov.mvhd.timescale
	traks := input.mp4.moov.traks
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
		// * styp
		// * sidx

		sidxs[i].fullbox.box.type = 0x73696478 // * string("sidxs[i]") to u32be
		sidxs[i].fullbox.box.size = 52
		//sidxs[i].fullbox.box.
		sidxs[i].fullbox.version = 1
		sidxs[i].reference_ID = trak_id
		sidxs[i].timescale = trak_timescale
		if trak_id == 1 {
			sidxs[i].earliest_presentation_time_extends = 0
		} else {
			sidxs[i].earliest_presentation_time_extends = 0
		}
		sidxs[i].first_offset_extends = i == 0 ? u64be(sidxs[i].fullbox.box.size) : 0
		sidxs[i].reference_count = 1
		sidxs[i].items = make([]SegmentIndexBoxItems, sidxs[i].reference_count)
		sidxs[i].items[0] = {
			    reference_type = 0,
			    referenced_size = 1618842, // file size
			    subsegment_duration = trak_id == 0 ? u32be(input.segment_duration) * trak_timescale: 0,
			    starts_with_SAP = 1,
			    SAP_type = 0, 
			    SAP_delta_time = 0
		}
	}

	return sidxs
}

create_moof :: proc(input: Input) -> (moof: Moof){
	moof.box.type = 0x6D6F6F66
	moof.mfhd.sequence_number = u32be(input.segment_number)
	moof.box.size = 8
	for i := 0; i < len(input.mp4.moov.traks); i += 1 {
		traf := create_traf(input)
		append(&moof.trafs, traf)
		moof.box.size += traf.box.size
	}
	return moof
}

create_traf :: proc(input: Input) -> (traf: Traf) {
	traf.box.type = 0x74726166
	traf.tfhd = create_tfhd(input, 0)
	traf.tfdt = create_tfdt(input)
	traf.trun = create_trun(input, 0, 0)
	traf.box.size = 8
	traf.box.size += traf.tfhd.fullbox.box.size + traf.tfdt.fullbox.box.size + traf.trun.fullbox.box.size
	return traf
}


TFHD_TYPE :: 0x74666864
// * trun flags
BASE_DATA_OFFSET_PRESENT 			:: 0x000001
SAMPLE_DESCRIPTION_INDEX_PRESENT 	:: 0x000002
DEFAULT_SAMPLE_DURATION_PRESENT 	:: 0x000008
DEFAULT_SAMPLE_SIZE_PRESENT 		:: 0x000010
DEFAULT_SAMPLE_FLAGS_PRESENT 		:: 0x000020
DURATION_IS_EMPTY 					:: 0x010000
DEFAULT_BASE_IS_MOOF 				:: 0x020000


create_tfhd :: proc(input: Input, tf_flags: int) -> (tfhd: Tfhd) {
	tfhd.fullbox.box.type = TFHD_TYPE
	tfhd.fullbox.version = 0
	flags := tf_flags
	tfhd.fullbox.flags = (^[3]byte)(&flags)^
	size: int 
	if tf_flags & BASE_DATA_OFFSET_PRESENT == BASE_DATA_OFFSET_PRESENT {
		size += size_of(u64be)
	}
	if tf_flags & SAMPLE_DESCRIPTION_INDEX_PRESENT == SAMPLE_DESCRIPTION_INDEX_PRESENT {
		size += size_of(u32be)
	}
	if tf_flags & DEFAULT_SAMPLE_DURATION_PRESENT == DEFAULT_SAMPLE_DURATION_PRESENT {
		size += size_of(u32be)
	}
	if tf_flags & DEFAULT_SAMPLE_SIZE_PRESENT == DEFAULT_SAMPLE_SIZE_PRESENT {
		size += size_of(u32be)
	}
	if tf_flags & DEFAULT_SAMPLE_FLAGS_PRESENT == DEFAULT_SAMPLE_FLAGS_PRESENT {
		size += size_of(u32be)
	}
	if tf_flags & DURATION_IS_EMPTY == DURATION_IS_EMPTY {
		size += size_of(u32be)
	}
	if tf_flags & DEFAULT_BASE_IS_MOOF == DEFAULT_BASE_IS_MOOF {
		size += size_of(u32be)
	}
	tfhd.fullbox.box.size = u32be(size)
	return tfhd
}

TFDT_TYPE :: 0x74666474

create_tfdt :: proc(input: Input) -> (tfdt: Tfdt) {
	tfdt.fullbox.box.type = TFDT_TYPE
	tfdt.baseMediaDecodeTime = 0
	tfdt.fullbox.box.size = 20
	return tfdt
}

TRUN_TYPE :: 0x7472756E
// * trun flags
DATA_OFFSET_PRESENT	:: 0x000001
FIRST_SAMPLE_FLAGS_PRESENT:: 0x000004
SAMPLE_DURATION_PRESENT:: 0x000100
SAMPLE_SIZE_PRESENT:: 0x000200
SAMPLE_FLAGS_PRESENT:: 0x000400
SAMPLE_COMPOSITION_TIME_OFFSETS_PRESENT:: 0x000800

create_trun :: proc(input: Input, tr_flags: int, tf_flags: int) -> (trun: Trun) {
	trun.fullbox.box.type = TRUN_TYPE
	flags := tr_flags
	trun.fullbox.flags = (^[3]byte)(&flags)^
	size: int
	if tf_flags & DATA_OFFSET_PRESENT == DATA_OFFSET_PRESENT {
		size += size_of(i32be)
	}
	if tf_flags & FIRST_SAMPLE_FLAGS_PRESENT == FIRST_SAMPLE_FLAGS_PRESENT {
		size += size_of(u32be)
	}

	sample_count := input.segment_video_sample_count

	for i:=0;i<sample_count;i+=1 {
		if tf_flags & SAMPLE_DURATION_PRESENT == SAMPLE_DURATION_PRESENT {
			// * CONCERNE SAMPLES
			// * sample‐duration‐present:	indicates	that	each	sample	has	its	own	duration,	otherwise	the	
			// * default	is	used.
			size += size_of(u32be)
		}
		if tf_flags & SAMPLE_SIZE_PRESENT == SAMPLE_SIZE_PRESENT {
			// * CONCERNE SAMPLES
			// * sample‐size‐present:	each	sample	has	its	own	size,	otherwise	the	default	is	used.	
			size += size_of(u32be)
		}
		if tf_flags & SAMPLE_FLAGS_PRESENT == SAMPLE_FLAGS_PRESENT {
			// * CONCERNE SAMPLES
			// * sample‐flags‐present:	each	sample	has	its	own	flags,	otherwise	the	default	is	used.
			size += size_of(u32be)
		}
		if tf_flags & SAMPLE_COMPOSITION_TIME_OFFSETS_PRESENT == SAMPLE_COMPOSITION_TIME_OFFSETS_PRESENT {
			// * CONCERNE SAMPLES
			// * sample‐composition‐time‐offsets‐present:	 each	 sample	 has	 a	 composition	 time	 offset
			size += size_of(u32be)
		}
	}

	trun.fullbox.box.size = u32be(size)
	return trun
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
