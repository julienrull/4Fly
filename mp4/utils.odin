package mp4

import "core:fmt"
import "core:math"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strings"

to_string :: proc(value: ^u32be) -> string {
	value_b := (^byte)(value)
	str := strings.string_from_ptr(value_b, size_of(u32be))
	return str
}

print_box :: proc(box: Box) {
	type := box.type
	type_b := (^byte)(&type)
	fmt.println("Type:", strings.string_from_ptr(type_b, size_of(u32be)))
	fmt.println("Size:", box.size)
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

// sample_to_chunk :: proc(trak: Trak, sample_number: int) -> (int, int) {
// 	stsc := trak.mdia.minf.stbl.stsc
// 	stsz := trak.mdia.minf.stbl.stsz
// 	sample_count_sum: int
// 	chunk_count_sum: int
// 	for i := 0; i < len(stsc.entries); i += 1 {
// 		stsc_entry := stsc.entries[i]

// 		// ? stsc_entry.first_chunk
// 		// ? stsc_entry.sample_description_index
// 		// ? stsc_entry.samples_per_chunk
// 		chunk_count := 0
// 		sample_count := 0
// 		if i == len(stsc.entries) - 1 {
// 			if sample_count_sum + int(stsc_entry.samples_per_chunk) == int(stsz.sample_count) {
// 				chunk_count = 1
// 				sample_count = int(stsc_entry.samples_per_chunk)
// 			} else {
// 				chunk_count = int(stsz.sample_count)
// 				sample_count = int(stsc_entry.samples_per_chunk)
// 			}
// 		} else {
// 			chunk_count = int(stsc.entries[i + 1].first_chunk - stsc_entry.first_chunk)
// 			sample_count = chunk_count * int(stsc_entry.samples_per_chunk)
// 		}
// 		// fmt.println("sample_count_sum + int(sample_count)", sample_count_sum, "i", i)
// 		if (sample_count_sum + int(sample_count) >= sample_number) {
// 			if chunk_count == 1 {
// 				chunk_count_sum += 1
// 				sample_count_sum += 1
// 				return chunk_count_sum,
// 					sample_number - sample_count_sum
// 			}else {
// 				for j := 0; j < int(chunk_count); j += 1 {
// 					if sample_count_sum +  int(stsc_entry.samples_per_chunk)>=
// 					sample_number {
						
// 						fmt.println("sample_count_sum", sample_count_sum, "chunk_count_sum", chunk_count_sum)
// 						fmt.println("sample_number", sample_number, "chunk_count_sum", chunk_count_sum)
// 						return chunk_count_sum,
// 						sample_number - sample_count_sum
// 					}
// 					chunk_count_sum += 1
// 					sample_count_sum += int(stsc_entry.samples_per_chunk)
// 				}
// 			}

// 		} else {
// 			chunk_count_sum += int(chunk_count)
// 			sample_count_sum += int(sample_count)
// 		}
// 	}

// 	return 0, 0
// }

sample_to_chunk :: proc(trak: Trak, sample_number: int) -> (chunk_number: int, sample_position: int) {
	stsc := trak.mdia.minf.stbl.stsc
	stsz := trak.mdia.minf.stbl.stsz

	samples_sum := 0
	chunk_sum := 0
	for i:=0;i<int(stsc.entry_count);i+=1{
		// * Get chunk info
		entry := stsc.entries[i]
		first_sample := samples_sum + 1
		chunk_count := 0
		if stsc.entry_count == 1 {
			chunk_count = int(stsz.sample_count)
		}else if i == int(stsc.entry_count) - 1 {
			chunk_count = 1 
		}else{
			chunk_count = int(stsc.entries[i+1].first_chunk - entry.first_chunk)
		}

		//chunk_count := i == len(stsc.entries) - 1 ? 1 : stsc.entries[i+1].first_chunk - entry.first_chunk
		sample_count := int(entry.samples_per_chunk) * chunk_count
		// * Check bound
		if sample_number < first_sample + int(sample_count) {
			fmt.println("sample_number", sample_number, "first_sample", first_sample, "sample_count", sample_count)
			fmt.println("first_sample + int(sample_count)", first_sample + int(sample_count))
			fmt.println("first_chunk", entry.first_chunk)
			fmt.println("chunk_count", chunk_count)
			fmt.println("samples_sum", chunk_sum)
			fmt.println("chunk_sum", chunk_sum)
			for j:=0;j<int(chunk_count);j+=1{
				first_sample = samples_sum + 1
				if sample_number < first_sample + int(entry.samples_per_chunk) {
					if chunk_count > 1 {
						chunk_number = int(entry.first_chunk) + j - 1
						sample_position = sample_number - first_sample + 1
					}else {
						chunk_number = int(entry.first_chunk) + j
						sample_position = sample_number - first_sample
					}
					return chunk_number, sample_position
				}
				samples_sum += int(entry.samples_per_chunk)
				chunk_sum += 1
			}
		} 
		// *
		samples_sum += int(sample_count)
		chunk_sum += int(chunk_count)
	}
	
	return chunk_number, sample_position
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
	chunk_number, sample_position := sample_to_chunk(trak, sample_number)
	chunk_offset := get_chunk_offset(trak, chunk_number)
	offset_size: u64 = 0
	for i := 0; i < sample_position - 1; i += 1 {
		offset_size += get_sample_size(trak, sample_number)
	}
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

create_fragment :: proc(mp4: Mp4, segment_index: int, segment_duration: f32) -> (sidx: Sidx) {
	// * Mp4 info
	mp4_duration := mp4.moov.mvhd.duration // TODO: need version checking
	mp4_timescale := mp4.moov.mvhd.timescale
	traks := mp4.moov.traks
	trak_count := len(traks)

	for i := 0; i < trak_count; i += 1 {
		// * Fragment info
		trak := traks[i]
		trak_id := trak.tkhd.track_ID
		trak_timescale := trak.mdia.mdhd.timescale

	}

	return sidx
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
