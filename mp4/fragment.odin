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
	sample_count_cum: u32be = 0
	//fmt.println("segment_number", segment_number)
	// * Get samples decoding times offsets
    if segment_begin_time > 0 {
        for stts in stts.entries {
            // * Variables
            sample_count := stts.sample_count
            sample_duration := stts.sample_delta
            stts_duration := sample_count * sample_duration
            // * Find segment range
            if sample_duration_cum + stts_duration > segment_begin_time {
                target_stts_begin := sample_duration_cum
                target_stts_end := sample_duration_cum + stts_duration
                remain_time_to_begin := segment_begin_time - target_stts_begin
                remain_sample_count := (remain_time_to_begin / stts.sample_delta)
				if remain_time_to_begin % stts.sample_delta != 0 {
					remain_sample_count += 1
				}
                sample_number = sample_count_cum + remain_sample_count
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

write_fragment :: proc(handle: os.Handle, number: u32be, duration: f64) -> FileError {
    fragment_number: u32be = number
    fragment_duration := duration
    trak_count := 2
    data_size_vide: u64be = 0
    data_size_soun: u64be = 0
    vide_duration: u64be = 0
    soun_duration: u64be = 0
    // OUTPUT HANDLE
    output := fopen(fmt.tprintf("seg-%d.m4s", fragment_number), os.O_CREATE | os.O_RDWR) or_return
    defer os.close(output)
    // READ
    vide_id := get_trak_number(handle, "vide") or_return
    soun_id := get_trak_number(handle, "soun") or_return

	ctts_vide_present := true
	ctts_soun_present := true
	stco_vide_present := true
	stco_soun_present := true

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
    stsc_vide := read_stsc(handle, vide_id) or_return
    stsc_soun := read_stsc(handle, soun_id) or_return

    ctts_vide, ctts_vide_err := read_ctts(handle, vide_id)
	if ctts_vide_err != nil || ctts_vide.entry_count == 0 {
		ctts_vide_present = false
	}
    ctts_soun, ctts_soun_err := read_ctts(handle, soun_id)
	if ctts_soun_err != nil || ctts_soun.entry_count == 0 {
		ctts_soun_present = false
	}
    stco_vide, stco_vide_err := read_stco(handle, vide_id)
	co64_vide := Co64V2{}
	if stco_vide_err != nil || stco_vide.entry_count == 0 {
		stco_vide_present = false
		co64_vide = read_co64(handle, vide_id) or_return
	}
	co64_soun := Co64V2{}
	stco_soun, stco_soun_err := read_stco(handle, soun_id)
	if stco_soun_err != nil || stco_soun.entry_count == 0 {
		stco_soun_present = false
		co64_soun = read_co64(handle, soun_id) or_return
	}

    stsz_vide := read_stsz(handle, vide_id) or_return
    stsz_soun := read_stsz(handle, soun_id) or_return
	// stz2 ???


    sample_number_begin_vide, sample_duration_begin_vide := get_segment_first_sampleV2(stts_vide, mdhd_vide.timescale, fragment_number, fragment_duration)
    sample_number_end_vide, sample_duration_end_vide := get_segment_first_sampleV2(stts_vide, mdhd_vide.timescale, fragment_number + 1, fragment_duration)
    sample_number_begin_soun, sample_duration_begin_soun := get_segment_first_sampleV2(stts_soun, mdhd_soun.timescale, fragment_number, fragment_duration)
    sample_number_end_soun, sample_duration_end_soun := get_segment_first_sampleV2(stts_soun, mdhd_soun.timescale, fragment_number + 1, fragment_duration)
	total_last_durations_vide: u32be
sample_number_end_vide -= 1
sample_number_end_soun -= 1
    for i in 1..<sample_number_begin_vide {
        total_last_durations_vide += get_sample_durationV2(stts_vide, i)
    }
	total_last_durations_soun: u32be
    for i in 1..<sample_number_begin_soun {
        total_last_durations_soun += get_sample_durationV2(stts_soun, i)
    }

    //trun
    trun_vide := TrunV2{}
    trun_vide.box.type = "trun"
    trun_vide.box.is_fullbox = true
    trun_vide.box.is_container = false
    trun_vide.box.is_large_size = false
    trun_vide.box.version = 0
    trun_vide.box.header_size = 12
    trun_vide.sample_count = sample_number_end_vide - sample_number_begin_vide + 1
    trun_vide.data_offset_present = true
    trun_vide.sample_duration_present = true
    trun_vide.sample_size_present = true
    trun_vide.sample_composition_time_offset_present = ctts_vide_present
    trun_vide.box.body_size = u64be(8 + (trun_vide.sample_count * 8))
    trun_vide.samples = make([]TrackRunBoxSample, trun_vide.sample_count)
	j := 0
    for i in sample_number_begin_vide..=sample_number_end_vide {
        trun_vide.samples[j].sample_duration = get_sample_durationV2(stts_vide, i)
		if ctts_vide_present {
			trun_vide.samples[j].sample_composition_time_offset = get_sample_presentation_offsetV2(ctts_vide, i)
			trun_vide.box.body_size += 4
		}
        trun_vide.samples[j].sample_size = get_sample_sizeV2(stsz_vide, i)
		data_size_vide += u64be(trun_vide.samples[j].sample_size)
		vide_duration += u64be(trun_vide.samples[j].sample_duration)
		j += 1
    }
    trun_vide.box.total_size = trun_vide.box.header_size + trun_vide.box.body_size

    trun_soun := TrunV2{}
    trun_soun.box.type = "trun"
    trun_soun.box.is_fullbox = true
    trun_soun.box.is_container = false
    trun_soun.box.is_large_size = false
    trun_soun.box.version = 0
    trun_soun.box.header_size = 12
    trun_soun.sample_count = sample_number_end_soun - sample_number_begin_soun + 1
    trun_soun.data_offset_present = true
    trun_soun.sample_duration_present = true
    trun_soun.sample_size_present = true
    trun_soun.sample_composition_time_offset_present = ctts_soun_present
    trun_soun.box.body_size = u64be(8 + (trun_soun.sample_count * 8))
    trun_soun.samples = make([]TrackRunBoxSample, trun_soun.sample_count)
	j = 0
    for i in sample_number_begin_soun..=sample_number_end_soun {
        trun_soun.samples[j].sample_duration = get_sample_durationV2(stts_soun, i)
		if ctts_soun_present {
			trun_soun.samples[j].sample_composition_time_offset = get_sample_presentation_offsetV2(ctts_soun, i)
			trun_soun.box.body_size += 4
		}
        trun_soun.samples[j].sample_size = get_sample_sizeV2(stsz_soun, i)
		data_size_soun += u64be(trun_soun.samples[j].sample_size)
		soun_duration += u64be(trun_soun.samples[j].sample_duration)
		j += 1
    }
	log.infof("Fragment %d, vide %f, soun %f", fragment_number,
		f64(vide_duration) / f64(mdhd_vide.timescale),
		f64(soun_duration) / f64(mdhd_soun.timescale))
    trun_soun.box.total_size = trun_soun.box.header_size + trun_soun.box.body_size
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
	tfhd_vide.default_sample_size = get_sample_sizeV2(stsz_vide, sample_number_begin_vide)
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
	tfhd_soun.default_sample_size = get_sample_sizeV2(stsz_soun, sample_number_begin_soun)
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
    mfhd.sequence_number = fragment_number + 1
    mfhd.box.total_size = mfhd.box.header_size + mfhd.box.body_size
    // moof
	moof := BoxV2{}
	moof.type = "moof"
    moof.is_container = true
    moof.header_size = 8
    moof.body_size = mfhd.box.total_size + traf_vide.total_size + traf_soun.total_size
    moof.total_size = moof.header_size + moof.body_size
	trun_vide.data_offset = i32be(moof.total_size) + 8
	trun_soun.data_offset = i32be(moof.total_size) + 8
	if soun_id == 2 {
		trun_soun.data_offset += i32be(data_size_vide)
	} else if vide_id == 2 {
		trun_vide.data_offset += i32be(data_size_soun)
	}
    //mdat
	mdat := BoxV2{}
	mdat.type = "mdat"
    mdat.is_container = false
    mdat.header_size = 8
    mdat.body_size = data_size_vide + data_size_soun
    mdat.total_size = mdat.header_size + mdat.body_size

    // sidx

	 shift: f64 = 0
	 vide_duration_scaled := f64(mdhd_vide.duration) / f64(mdhd_vide.timescale)
	 soun_duration_scaled := f64(mdhd_soun.duration) / f64(mdhd_soun.timescale)
	 if vide_duration_scaled < soun_duration_scaled {
		 shift = vide_duration_scaled - soun_duration_scaled
	 }

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
    sidx_vide.first_offset = u64be((trak_count - vide_id) * 52)
    sidx_vide.earliest_presentation_time = u64be(total_last_durations_vide)
    sidx_vide.reference_count = 1
    sidx_vide.items = make([]SegmentIndexBoxItems, sidx_vide.reference_count)
    sidx_vide.items[0].reference_type = 0
    sidx_vide.items[0].referenced_size = u32be(moof.total_size + mdat.total_size)
    sidx_vide.items[0].subsegment_duration = u32be(vide_duration) //u32be(fragment_duration * f64(mdhd_vide.timescale))
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
    sidx_soun.first_offset = u64be((trak_count - soun_id) * 52)
    sidx_soun.earliest_presentation_time = u64be(total_last_durations_soun) + u64be(shift * f64(mdhd_soun.timescale))
    sidx_soun.reference_count = 1
    sidx_soun.items = make([]SegmentIndexBoxItems, sidx_vide.reference_count)
    sidx_soun.items[0].reference_type = 0
    sidx_soun.items[0].referenced_size = u32be(moof.total_size + mdat.total_size)
    sidx_soun.items[0].subsegment_duration = u32be(soun_duration) //u32be(fragment_duration * f64(mdhd_soun.timescale))
    sidx_soun.items[0].starts_with_SAP = 1
    sidx_soun.items[0].SAP_type = 0
    sidx_soun.items[0].SAP_delta_time = 0

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
	size_writed: u64be = 0
	for sample in sample_number_begin_vide..=sample_number_end_vide {
		chunk_number, first_chunk_sample := sample_to_chunkV2(stsc_vide, sample)
		sample_offset, sample_size: u64be = 0, 0
		if stsc_vide.entry_count <= 1 {
			chunk_number = sample
		}
		chunk_offset := get_chunk_offsetV2(chunk_number, stco_vide, co64_vide)
		if(first_chunk_sample == 0){// TODO: write the right condition
			sample_offset = chunk_offset
			sample_size = u64be(get_sample_sizeV2(stsz_vide, sample))
		}else{
			sample_offset, sample_size = get_sample_offsetV2(stsc_vide, stsz_vide, chunk_offset, first_chunk_sample, sample)
		}
		fseek(handle, i64(sample_offset), os.SEEK_SET)
		buffer := make([]u8, sample_size)
		defer delete(buffer)
		fread(handle, buffer)
		fwrite(output, buffer)
		size_writed += sample_size
		//data := video_file_b[sample_offset : sample_offset + sample_size]
		//mdat.data = slice.concatenate([][]byte{mdat.data,data})
	}
	for sample in sample_number_begin_soun..=sample_number_end_soun {
		chunk_number, first_chunk_sample := sample_to_chunkV2(stsc_soun, sample)
		sample_offset, sample_size : u64be = 0, 0
		if stsc_soun.entry_count <= 1 {
			chunk_number = sample
		}
		chunk_offset := get_chunk_offsetV2(chunk_number, stco_soun, co64_soun)
		if(first_chunk_sample == 0){// TODO: write the right condition
			sample_offset = chunk_offset
			sample_size = u64be(get_sample_sizeV2(stsz_soun, sample))
		}else{
			sample_offset, sample_size = get_sample_offsetV2(stsc_soun, stsz_soun, chunk_offset, first_chunk_sample, sample)
		}
		fseek(handle, i64(sample_offset), os.SEEK_SET)
		buffer := make([]u8, sample_size)
		defer delete(buffer)
		fread(handle, buffer)
		fwrite(output, buffer)
		size_writed += sample_size
		//data := video_file_b[sample_offset : sample_offset + sample_size]
		//mdat.data = slice.concatenate([][]byte{mdat.data,data})
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
