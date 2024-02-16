package mp4

import "core:os"
import "core:fmt"
import "core:log"

get_trak_number :: proc(handle: os.Handle, type: string) -> (number: int, error: FileError) {
    number = 1
    hdlr := read_hdlr(handle, number) or_return
    for hdlr.handler_type != type {
        number += 1
        hdlr = read_hdlr(handle, number) or_return
    }
    return number, nil
}


get_segment_first_sampleV2 :: proc(stts: SttsV2, timescale: u32be, segment_number: u32be, segment_duration: f64) -> (sample_number: u32be, sample_duration: u32be) {
	// * Variables
	segment_duration_scaled := u32be(segment_duration * f64(timescale))
	segment_begin_time := segment_duration_scaled * segment_number
	sample_number = 1
	sample_duration_cum: u32be
	sample_count_cum: u32be
	//fmt.println("segment_number", segment_number)
	// * Get samples decoding times offsets
    if segment_begin_time > 0 {
        for stts in stts.entries {
            // * Variables
            sample_count := stts.sample_count
            sample_duration := stts.sample_delta
            stts_duration := sample_count * sample_duration
            // * Find segment range
            if sample_duration_cum + stts_duration >= segment_begin_time {
                target_stts_begin := sample_duration_cum
                target_stts_end := sample_duration_cum + stts_duration
                remain_time_to_begin := segment_begin_time - target_stts_begin
                reamain_sample_time := (remain_time_to_begin / stts.sample_delta)
                sample_number_begin := sample_duration_cum + reamain_sample_time
                //sample_number = sample_number_begin + 1
                sample_number = sample_count_cum + reamain_sample_time
                sample_duration = stts.sample_delta
                return sample_number, sample_duration
            }
            sample_count_cum += sample_count
            sample_duration_cum += stts_duration
        }
    }
	return sample_number, stts.entries[0].sample_delta
}


get_sample_durationV2 :: proc(stts: SttsV2, sample_number: u32be) -> (sample_duration: u32be){
	sample_cum: u32be = 1
	for entry in stts.entries {
		if sample_cum + entry.sample_count >  sample_number {
			sample_duration = entry.sample_delta
			//fmt.println(sample_duration)
			break
		}
		sample_cum += entry.sample_count
	}
	return sample_duration
}
get_sample_presentation_offsetV2 :: proc(ctts: CttsV2, sample_number: u32be) -> (presentation_offset: u32be){
	sample_sum: u32be = 1
	if(ctts.entry_count > 0){
		for entry in ctts.entries {
			if sample_sum + entry.sample_count >  sample_number {
				presentation_offset = entry.sample_offset
				break
			}
			sample_sum += entry.sample_count
		}
	}
	return presentation_offset
}

get_sample_sizeV2 :: proc(stsz: StszV2, sample_number: u32be) -> (sample_size: u32be) {
	if stsz.sample_size > 0 {
		sample_size = stsz.sample_size
	} else {
		if stsz.sample_count > 0 {
			sample_size = stsz.entries[sample_number - 1]
		}
		//else {
		//	if stz2.sample_count > 0 {
		//		samples_per_entry:u32be = 0
		//		switch stz2.field_size {
		//		case 4:
		//			samples_per_entry = 8
		//		case 8:
		//			samples_per_entry = 4
		//		case 16:
		//			samples_per_entry = 2
		//		}
		//		index := sample_number / samples_per_entry
		//		offset := ((sample_number % samples_per_entry) - 1) * samples_per_entry
		//		sample_size = u64(stz2.entries_sizes[index - 1] << u64(offset))
		//	}
		//}
	}
	return sample_size
}

write_fragment :: proc(handle: os.Handle) -> FileError {
    fragment_number: u32be = 1
    fragment_duration := 3.7
    trak_count := 2
    data_size_vide: u64be = 0
    data_size_soun: u64be = 0
    // OUTPUT HANDLE
    output := fopen(fmt.tprintf("seg-%d.m4s", fragment_number), os.O_CREATE | os.O_RDWR) or_return
    defer os.close(output)
    // READ
    vide_id := get_trak_number(handle, "vide") or_return
    soun_id := get_trak_number(handle, "soun") or_return

    // WRITE
    // styp (=ftyp)
    styp := read_ftyp(handle) or_return
    styp.box.type = "styp"



    mvhd := read_mvhd(handle, vide_id) or_return

    tkhd_vide := read_tkhd(handle, vide_id) or_return
    tkhd_soun := read_tkhd(handle, soun_id) or_return
    mdhd_vide := read_mdhd(handle, vide_id) or_return
    mdhd_soun := read_mdhd(handle, soun_id) or_return
    hdlr_vide := read_hdlr(handle, vide_id) or_return
    hdlr_soun := read_hdlr(handle, soun_id) or_return
    stts_vide := read_stts(handle, vide_id) or_return
    stts_soun := read_stts(handle, soun_id) or_return
    //ctts_vide := read_ctts(handle, vide_id) or_return
    //ctts_soun := read_ctts(handle, soun_id) or_return
    stsc_vide := read_stsc(handle, vide_id) or_return
    stsc_soun := read_stsc(handle, soun_id) or_return
    co64_vide := read_co64(handle, vide_id) or_return
    co64_soun := read_co64(handle, soun_id) or_return
    //stco_vide := read_stco(handle, vide_id) or_return
    //stco_soun := read_stco(handle, soun_id) or_return

    stsz_vide := read_stsz(handle, vide_id) or_return
    stsz_soun := read_stsz(handle, soun_id) or_return


    sample_number_begin_vide, sample_duration_begin_vide := get_segment_first_sampleV2(stts_vide, mdhd_vide.timescale, fragment_number, fragment_duration)
    sample_number_end_vide, sample_duration_end_vide := get_segment_first_sampleV2(stts_vide, mdhd_vide.timescale, fragment_number + 1, fragment_duration)
    sample_number_begin_soun, sample_duration_begin_soun := get_segment_first_sampleV2(stts_soun, mdhd_soun.timescale, fragment_number, fragment_duration)
    sample_number_end_soun, sample_duration_end_soun := get_segment_first_sampleV2(stts_soun, mdhd_soun.timescale, fragment_number + 1, fragment_duration)
    //trun
    trun_vide := TrunV2{}
    trun_vide.box.type = "trun"
    trun_vide.box.is_fullbox = true
    trun_vide.box.is_container = false
    trun_vide.box.is_large_size = false
    trun_vide.box.version = 0
    trun_vide.box.header_size = 12
    trun_vide.sample_count = sample_number_end_vide - sample_number_begin_vide
    trun_vide.data_offset_present = true
    trun_vide.data_offset = 0 // TODO
    trun_vide.first_sample_flags_present = false
    trun_vide.sample_duration_present = true
    trun_vide.sample_size_present = true
    trun_vide.sample_flags_present = false
    trun_vide.sample_composition_time_offset_present = false
    trun_vide.box.body_size = u64be(8 + (trun_vide.sample_count * 8))
    trun_vide.box.total_size = trun_vide.box.header_size + trun_vide.box.body_size
    trun_vide.samples = make([]TrackRunBoxSample, trun_vide.sample_count)
	j := 0
    for i in sample_number_begin_vide..<sample_number_end_vide {
        trun_vide.samples[j].sample_duration = get_sample_durationV2(stts_vide, i)
        //trun_vide.samples[i].sample_composition_time_offset = get_sample_presentation_offsetV2(ctts_vide, i + 1)
        trun_vide.samples[j].sample_size = get_sample_sizeV2(stsz_vide, i)
		data_size_vide += u64be(trun_vide.samples[j].sample_size)
		j += 1
    }

    trun_soun := TrunV2{}
    trun_soun.box.type = "trun"
    trun_soun.box.is_fullbox = true
    trun_soun.box.is_container = false
    trun_soun.box.is_large_size = false
    trun_soun.box.version = 0
    trun_soun.box.header_size = 12
    trun_soun.sample_count = sample_number_end_soun - sample_number_begin_soun
    trun_soun.data_offset_present = true
    trun_soun.data_offset = 0 // TODO
    trun_soun.first_sample_flags_present = false
    trun_soun.sample_duration_present = true
    trun_soun.sample_size_present = true
    trun_soun.sample_flags_present = false
    trun_soun.sample_composition_time_offset_present = false
    trun_soun.box.body_size = u64be(8 + (trun_soun.sample_count * 8))
    trun_soun.box.total_size = trun_soun.box.header_size + trun_soun.box.body_size
    trun_soun.samples = make([]TrackRunBoxSample, trun_soun.sample_count)
	j = 0
    for i in sample_number_begin_soun..<sample_number_end_soun {
        trun_soun.samples[j].sample_duration = get_sample_durationV2(stts_soun, i)
        //trun_vide.samples[i].sample_composition_time_offset = get_sample_presentation_offsetV2(ctts_vide, i + 1)
        trun_soun.samples[j].sample_size = get_sample_sizeV2(stsz_soun, i)
		data_size_soun += u64be(trun_soun.samples[j].sample_size)
		j += 1
    }
    // tfdt
	tfdt_vide := TfdtV2{}
	tfdt_vide.box.type = "tfdt"
    tfdt_vide.box.is_fullbox = true
    tfdt_vide.box.is_container = false
    tfdt_vide.box.is_large_size = false
    tfdt_vide.box.version = 1
    tfdt_vide.box.header_size = 12
    tfdt_vide.box.body_size = 8
	tfdt_vide.baseMediaDecodeTime = u64be(fragment_duration * f64(mdhd_vide.timescale) * f64(fragment_number))
    tfdt_vide.box.total_size = tfdt_vide.box.header_size + tfdt_vide.box.body_size

	tfdt_soun := TfdtV2{}
	tfdt_soun.box.type = "tfdt"
    tfdt_soun.box.is_fullbox = true
    tfdt_soun.box.is_container = false
    tfdt_soun.box.is_large_size = false
    tfdt_soun.box.version = 1
    tfdt_soun.box.header_size = 12
    tfdt_soun.box.body_size = 8
	tfdt_soun.baseMediaDecodeTime = u64be(fragment_duration * f64(mdhd_soun.timescale) * f64(fragment_number))
    tfdt_soun.box.total_size = tfdt_soun.box.header_size + tfdt_soun.box.body_size
    // tfhd
	tfhd_vide := TfhdV2{}
	tfhd_vide.box.type = "tfhd"
    tfhd_vide.box.is_fullbox = true
    tfhd_vide.box.is_container = false
    tfhd_vide.box.is_large_size = false
    tfhd_vide.box.version = 0
    tfhd_vide.box.header_size = 12
	tfhd_vide.track_ID = tkhd_vide.track_ID
	tfhd_vide.default_sample_duration_present = true
	tfhd_vide.default_sample_size_present = true
	tfhd_vide.default_sample_duration = sample_duration_begin_vide
	tfhd_vide.default_sample_size = get_sample_sizeV2(stsz_vide, sample_duration_begin_vide)
    tfhd_vide.box.body_size = 12
    tfhd_vide.box.total_size = tfhd_vide.box.header_size + tfhd_vide.box.body_size

	tfhd_soun := TfhdV2{}
	tfhd_soun.box.type = "tfhd"
    tfhd_soun.box.is_fullbox = true
    tfhd_soun.box.is_container = false
    tfhd_soun.box.is_large_size = false
    tfhd_soun.box.version = 0
    tfhd_soun.box.header_size = 12
	tfhd_soun.track_ID = tkhd_soun.track_ID
	tfhd_soun.default_sample_duration_present = true
	tfhd_soun.default_sample_size_present = true
	tfhd_soun.default_sample_duration = sample_duration_begin_soun
	tfhd_soun.default_sample_size = get_sample_sizeV2(stsz_soun, sample_duration_begin_soun)
    tfhd_soun.box.body_size = 12
    tfhd_soun.box.total_size = tfhd_soun.box.header_size + tfhd_soun.box.body_size
    // traf
	traf_vide := BoxV2{}
	traf_vide.type = "traf"
    traf_vide.is_container = true
    traf_vide.header_size = 8
    traf_vide.body_size = tfhd_vide.box.total_size + tfdt_vide.box.total_size + trun_vide.box.total_size
    traf_vide.total_size = traf_vide.header_size + traf_vide.body_size

	traf_soun := BoxV2{}
	traf_soun.type = "traf"
    traf_soun.is_container = true
    traf_soun.header_size = 8
    traf_soun.body_size = tfhd_soun.box.total_size + tfdt_soun.box.total_size + trun_soun.box.total_size
    traf_soun.total_size = traf_soun.header_size + traf_soun.body_size
    // mfhd
	mfhd := MfhdV2{}
	mfhd.box.type = "mfhd"
    mfhd.box.is_fullbox = true
    mfhd.box.is_container = false
    mfhd.box.is_large_size = false
    mfhd.box.version = 0
    mfhd.box.header_size = 12
    mfhd.box.body_size = 4
    mfhd.sequence_number = fragment_number
    mfhd.box.total_size = mfhd.box.header_size + mfhd.box.body_size
    // moof
	moof := BoxV2{}
	moof.type = "moof"
    moof.is_container = true
    moof.header_size = 8
    moof.body_size = mfhd.box.total_size + traf_vide.total_size + traf_soun.total_size
    moof.total_size = moof.header_size + moof.body_size
    // sidx
    sidx_vide := SidxV2{}
    sidx_vide.box.type = "sidx"
    sidx_vide.box.is_fullbox = true
    sidx_vide.box.is_container = false
    sidx_vide.box.is_large_size = false
    sidx_vide.box.version = 1
    sidx_vide.box.header_size = 12
    sidx_vide.box.body_size = 40
    sidx_vide.box.total_size = 52
    sidx_vide.reference_ID = tkhd_vide.track_ID
    sidx_vide.timescale = mdhd_vide.timescale
    sidx_vide.first_offset = u64be(trak_count * 52 * 2)
    sidx_vide.earliest_presentation_time = 0 // TODO
    sidx_vide.reference_count = 1
    sidx_vide.items = make([]SegmentIndexBoxItems, sidx_vide.reference_count)
    sidx_vide.items[0].reference_type = 0
    sidx_vide.items[0].referenced_size = 0// TODO: size moof + size mdate
    sidx_vide.items[0].subsegment_duration = u32be(tkhd_vide.duration)
    sidx_vide.items[0].starts_with_SAP = 1
    sidx_vide.items[0].SAP_type = 0
    sidx_vide.items[0].SAP_delta_time = 0

    sidx_soun := SidxV2{}
    sidx_soun.box.type = "sidx"
    sidx_soun.box.is_fullbox = true
    sidx_soun.box.is_container = false
    sidx_soun.box.is_large_size = false
    sidx_soun.box.version = 1
    sidx_soun.box.header_size = 12
    sidx_soun.box.header_size = 12
    sidx_soun.box.body_size = 40
    sidx_soun.box.total_size = 52
    sidx_soun.reference_ID = tkhd_soun.track_ID
    sidx_soun.timescale = mdhd_soun.timescale
    sidx_soun.first_offset = u64be(trak_count * 52)
    sidx_soun.earliest_presentation_time = 0 // TODO
    sidx_soun.reference_count = 1
    sidx_soun.items = make([]SegmentIndexBoxItems, sidx_vide.reference_count)
    sidx_soun.items[0].reference_type = 0
    sidx_soun.items[0].referenced_size = 0// TODO: size moof + size mdate
    sidx_soun.items[0].subsegment_duration = u32be(tkhd_soun.duration)
    sidx_soun.items[0].starts_with_SAP = 1
    sidx_soun.items[0].SAP_type = 0
    sidx_soun.items[0].SAP_delta_time = 0
    //mdat

	mdat := BoxV2{}
	mdat.type = "mdat"
    mdat.is_container = false
    mdat.header_size = 8
    mdat.body_size = data_size_vide + data_size_soun
    mdat.total_size = mdat.header_size + mdat.body_size

    // Writing boxes
    write_ftyp(output, styp) or_return
    write_sidx(output, sidx_vide) or_return
    write_sidx(output, sidx_soun) or_return
	write_box(output, moof)
	write_mfhd(output, mfhd)
	write_box(output, traf_vide)
	write_tfhd(output, tfhd_vide)
	write_tfdt(output, tfdt_vide)
    write_trun(output, trun_vide) or_return
	write_box(output, traf_soun)
	write_tfhd(output, tfhd_soun)
	write_tfdt(output, tfdt_soun)
    write_trun(output, trun_soun) or_return
	write_box(output, mdat)

	// writing data

	for sample in sample_number_begin_vide..<sample_number_end_vide {
		chunk_number, first_chunk_sample := sample_to_chunkV2(stsc_vide, sample)
		sample_offset, sample_size : u64be = 0, 0
		if stsc_vide.entry_count <= 1 {
			chunk_number = sample
		}
		chunk_offset := get_chunk_offsetV2(chunk_number,  co64 = co64_vide)
		if(first_chunk_sample == 0){// TODO: write the right condition
			sample_offset = chunk_offset
			sample_size = u64be(get_sample_sizeV2(stsz_vide, sample))
		}else{
			sample_offset, sample_size = get_sample_offsetV2(stsc_vide, stsz_vide, chunk_offset, first_chunk_sample, sample)
		}
		buf_size := sample_size
		buffer := make([]u8, sample_size)
		fread(handle, buffer)
		fwrite(output, buffer)
		//data := video_file_b[sample_offset : sample_offset + sample_size]
		//mdat.data = slice.concatenate([][]byte{mdat.data,data})
		delete(buffer)
	}
	for sample in sample_number_begin_soun..<sample_number_end_soun {
		chunk_number, first_chunk_sample := sample_to_chunkV2(stsc_soun, sample)
		sample_offset, sample_size : u64be = 0, 0
		if stsc_soun.entry_count <= 1 {
			chunk_number = sample
		}
		chunk_offset := get_chunk_offsetV2(chunk_number,  co64 = co64_soun)
		if(first_chunk_sample == 0){// TODO: write the right condition
			sample_offset = chunk_offset
			sample_size = u64be(get_sample_sizeV2(stsz_soun, sample))
		}else{
			sample_offset, sample_size = get_sample_offsetV2(stsc_soun, stsz_soun, chunk_offset, first_chunk_sample, sample)
		}
		buf_size := sample_size
		buffer := make([]u8, sample_size)
		fread(handle, buffer)
		fwrite(output, buffer)
		//data := video_file_b[sample_offset : sample_offset + sample_size]
		//mdat.data = slice.concatenate([][]byte{mdat.data,data})
		delete(buffer)
	}
    return nil
}

get_sample_offsetV2 :: proc(stsc: StscV2, stsz: StszV2, chunk_offset: u64be, first_chunk_sample: u32be, sample_number: u32be) -> (sample_offset: u64be,
sample_size: u64be) {
	sample_offset = chunk_offset
	if stsc.entry_count > 1 {
		for sample in first_chunk_sample..=sample_number {
			if(sample == sample_number){
				sample_size = u64be(get_sample_sizeV2(stsz, sample))
			}else{
				sample_offset += u64be(get_sample_sizeV2(stsz, sample))
			}
		}
	}else{
		sample_size = u64be(get_sample_sizeV2(stsz, sample_number))
	}
	return sample_offset, sample_size
}

get_chunk_offsetV2 :: proc(chunk_number: u32be, stco: StcoV2 = {}, co64: Co64V2 = {}) -> (chunk_offset: u64be) {
	if co64.box.type == "co64" {
		chunk_offset = u64be(co64.entries[chunk_number - 1])
	}else if stco.box.type == "stco" {
		chunk_offset = u64be(stco.entries[chunk_number - 1])
	}else {
		panic("ERROR: no chuck boxes (stco or co64) found.")
		// TODO
	}
	return chunk_offset
}

sample_to_chunkV2 :: proc(stsc: StscV2, sample_number: u32be) -> (chunk_number: u32be, first_sample: u32be) {
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
				cn := (sample_number - samples_sum) + first_chunk
				return cn, 0
			}else {
				chunk_count = stsc.entries[i + 1].first_chunk - first_chunk
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

	}
		return chunk_number, first_sample
}
