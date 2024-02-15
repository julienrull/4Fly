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
                fmt.println("sample_number : ", sample_number)
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

write_fragment :: proc(handle: os.Handle) -> FileError {
    fragment_number: u32be = 1
    fragment_duration := 3.7
    trak_count := 2
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


    log.debug(vide_id, soun_id)

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
    co64_vide := read_co64(handle, vide_id) or_return
    co64_soun := read_co64(handle, soun_id) or_return
    //stco_vide := read_stco(handle, vide_id) or_return
    //stco_soun := read_stco(handle, soun_id) or_return

    stsz_vide := read_stsz(handle, vide_id) or_return
    stsz_soun := read_stsz(handle, soun_id) or_return


    sample_number_begin, sample_duration_begin := get_segment_first_sampleV2(stts_vide, mdhd_vide.timescale, fragment_number, fragment_duration)
    sample_number_end, sample_duration_end := get_segment_first_sampleV2(stts_vide, mdhd_vide.timescale, fragment_number + 1, fragment_duration)
    //trun
    trun_vide := TrunV2{}
    trun_vide.box.type = "trun"
    trun_vide.box.is_fullbox = true
    trun_vide.box.is_container = false
    trun_vide.box.is_large_size = false
    trun_vide.box.version = 0
    trun_vide.box.header_size = 12
    trun_vide.sample_count = sample_number_end - sample_number_begin
    trun_vide.data_offset_present = true
    trun_vide.first_sample_flags_present = false
    trun_vide.data_offset = 0 // TODO
    trun_vide.sample_duration_present = true
    trun_vide.sample_size_present = true
    trun_vide.sample_flags_present = true
    trun_vide.sample_composition_time_offset_present = true
    trun_vide.box.body_size = u64be(8 + (trun_vide.sample_count * 16))
    trun_vide.box.total_size = trun_vide.box.header_size + trun_vide.box.body_size
    trun_vide.samples = make([]TrackRunBoxSample, trun_vide.sample_count)
    for i in 0..<trun_vide.sample_count {
        trun_vide.samples[i].sample_duration = get_sample_durationV2(stts_vide, i + 1)
    }
    trun_vide.box.body_size = 0 // TODO
    trun_vide.box.total_size = 0 // TODO
    // tfdt
    // tfhd
    // traf
    // mfhd
    // moof
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

    // Writing
    write_ftyp(output, styp) or_return
    write_sidx(output, sidx_vide) or_return
    write_sidx(output, sidx_soun) or_return
    write_trun(output, trun_vide) or_return

    return nil
}
