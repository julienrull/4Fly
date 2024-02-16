package mp4

import "core:fmt"
import "core:mem"
import "core:slice"
import "core:os"
import "core:bytes"

// SegmentIndexBox
Sidx :: struct {
	// sidx
	fullbox:                            FullBox,
	reference_ID:                       u32be,
	timescale:                          u32be,
	earliest_presentation_time:         u32be,
	earliest_presentation_time_extends: u64be,
	first_offset:                       u32be,
	first_offset_extends:               u64be,
	reserved:                           u16be,
	reference_count:                    u16be,
	items:                              []SegmentIndexBoxItems,
}

SegmentIndexBoxItems :: struct {
	reference_type:      byte, // 1 bit
	referenced_size:     u32be, // 31 bit
	subsegment_duration: u32be,
	starts_with_SAP:     byte, // 1 bit
	SAP_type:            byte, // 3 bit
	SAP_delta_time:      u32be, // 28 bit
}


SidxV2 :: struct {
	// sidx
	box:								BoxV2,
	reference_ID:                       u32be,
	timescale:                          u32be,
	earliest_presentation_time:			u64be,
	first_offset:						u64be,
	//reserved:                           u16be,
	reference_count:                    u16be,
	items:                              []SegmentIndexBoxItems,
}

read_segment_indexes :: proc(handle: os.Handle, count: u16be) -> (items: []SegmentIndexBoxItems, error: FileError) {
	items = make([]SegmentIndexBoxItems, count)
	buffer := [12]u8{}
	for i in 0..<len(items){
		fread(handle, buffer[:]) or_return
		tmp: []u32be = transmute([]u32be)buffer[:]
		fmt.printf("%32b\n", tmp[2])
		items[i].reference_type = byte(tmp[0] >> 31)
		items[i].referenced_size = tmp[0] & 0x7FFFFFFF
		items[i].subsegment_duration = tmp[1]
		items[i].starts_with_SAP = byte(tmp[2] >> 31)
		items[i].SAP_type = byte((tmp[2]  >> 28))
		items[i].SAP_delta_time = tmp[2] & 0x0FFFFFFF
	}
	return items, nil
}

write_segment_indexes :: proc(buffer: ^bytes.Buffer, atom: SidxV2) -> FileError {
	for i in 0..<len(atom.items){
		reference_type := u32be(atom.items[i].reference_type)  << 31
		temp := reference_type | atom.items[i].referenced_size
		bytes.buffer_write_ptr(buffer, &temp, 4)
		subsegment_duration := atom.items[i].subsegment_duration
		bytes.buffer_write_ptr(buffer, &subsegment_duration, 4)
		starts_with_SAP := u32be(atom.items[i].starts_with_SAP) << 31
		SAP_type := u32be(atom.items[i].SAP_type) << 28
		temp = starts_with_SAP | SAP_type | atom.items[i].SAP_delta_time
		bytes.buffer_write_ptr(buffer, &temp, 4)
	}
	return nil
}

read_sidx :: proc(handle: os.Handle, id: int = 1) -> (atom: SidxV2, err: FileError) {
    box := select_box(handle, "sidx", id) or_return
    atom.box = box
    fseek(handle, i64(box.header_size), os.SEEK_CUR) or_return
    buffer := [8]u8{}
    fread(handle, buffer[:]) or_return
	data := transmute([]u32be)buffer[:]
    atom.reference_ID = data[0]
    atom.timescale = data[1]
	if box.version == 1 {
		fread(handle, buffer[:]) or_return
		atom.earliest_presentation_time = transmute(u64be)buffer
		fread(handle, buffer[:]) or_return
		atom.first_offset = transmute(u64be)buffer
	}else {
		fread(handle, buffer[:]) or_return
		data = transmute([]u32be)buffer[:]
    	atom.earliest_presentation_time = u64be(data[0])
    	atom.first_offset = u64be(data[1])
	}
    fseek(handle, 2, os.SEEK_CUR) or_return
    fread(handle, buffer[:2]) or_return
    atom.reference_count = (transmute([]u16be)buffer[:2])[0]
    atom.items = read_segment_indexes(handle, atom.reference_count) or_return
    return atom, nil
}


write_sidx :: proc(handle: os.Handle, atom: SidxV2) -> FileError {
    data := bytes.Buffer{}
	atom_cpy := atom
    bytes.buffer_init(&data, []u8{})
    bytes.buffer_write_ptr(&data, &atom_cpy.reference_ID, 4)
    bytes.buffer_write_ptr(&data, &atom_cpy.timescale, 4)
	if atom.box.version == 1 {
		bytes.buffer_write_ptr(&data, &atom_cpy.earliest_presentation_time, 8)
		bytes.buffer_write_ptr(&data, &atom_cpy.first_offset, 8)
		atom_cpy.box.body_size += 16
	}else {
		earliest_presentation_time := u32be(atom.earliest_presentation_time)
		bytes.buffer_write_ptr(&data, &earliest_presentation_time, 4)
		first_offset := u32be(atom.first_offset)
		bytes.buffer_write_ptr(&data, &first_offset, 4)
		atom_cpy.box.body_size += 8
	}
	pre_defined: u16be = 0
	bytes.buffer_write_ptr(&data, &pre_defined, 2)
	bytes.buffer_write_ptr(&data, &atom_cpy.reference_count, 2)
	write_segment_indexes(&data, atom_cpy)
    // TODO: handle io error for buffer_to_bytes
    write_box(handle, atom_cpy.box) or_return
    total_write := fwrite(handle, bytes.buffer_to_bytes(&data)) or_return
    bytes.buffer_destroy(&data)
	return nil
}

deserialize_sidx :: proc(data: []byte) -> (sidx: Sidx, acc: u64) {
	fullbox, fullbox_size := deserialize_fullbox(data)
	sidx.fullbox = fullbox
	acc += fullbox_size
	sidx.reference_ID = (^u32be)(&data[acc])^
	acc += size_of(u32be)
	sidx.timescale = (^u32be)(&data[acc])^
	acc += size_of(u32be)
	if fullbox.version == 1 {
		sidx.earliest_presentation_time_extends = (^u64be)(&data[acc])^
		acc += size_of(u64be)
		sidx.first_offset_extends = (^u64be)(&data[acc])^
		acc += size_of(u64be)
	} else {
		sidx.earliest_presentation_time = (^u32be)(&data[acc])^
		acc += size_of(u32be)
		sidx.first_offset = (^u32be)(&data[acc])^
		acc += size_of(u32be)
	}
	sidx.reserved = (^u16be)(&data[acc])^
	acc += size_of(u16be)
	sidx.reference_count = (^u16be)(&data[acc])^
	acc += size_of(u16be)
	sidx.items = make([]SegmentIndexBoxItems, sidx.reference_count)

	for i := 0; i < int(sidx.reference_count); i += 1 {
		tmp: u32be = (^u32be)(&data[acc])^
		sidx.items[i].reference_type = (byte)((tmp & 0x00000001))
		sidx.items[i].referenced_size = tmp >> 1
		acc += size_of(u32be)
		sidx.items[i].subsegment_duration = (^u32be)(&data[acc])^
		acc += size_of(u32be)
		tmp = (^u32be)(&data[acc])^
		sidx.items[i].starts_with_SAP = (byte)((tmp & 0x00000001))
		sidx.items[i].SAP_type = (byte)(((tmp >> 1) & 0x00000007))
		sidx.items[i].SAP_delta_time = tmp >> 4
		acc += size_of(u32be)
	}
	return sidx, acc
}

serialize_sidx :: proc(sidx: Sidx) -> (data: []byte) {
	fullbox_b := serialize_fullbox(sidx.fullbox)
	reference_ID := sidx.reference_ID
	reference_ID_b := (^[4]byte)(&reference_ID)^
	data = slice.concatenate([][]byte{fullbox_b[:], reference_ID_b[:]})
	timescale := sidx.timescale
	timescale_b := (^[4]byte)(&timescale)^
	data = slice.concatenate([][]byte{data[:], timescale_b[:]})
	if sidx.fullbox.version == 1 {
		earliest_presentation_time_extends := sidx.earliest_presentation_time_extends
		earliest_presentation_time_extends_b := (^[8]byte)(&earliest_presentation_time_extends)^
		data = slice.concatenate([][]byte{data[:], earliest_presentation_time_extends_b[:]})

		first_offset_extends := sidx.first_offset_extends
		first_offset_extends_b := (^[8]byte)(&first_offset_extends)^
		data = slice.concatenate([][]byte{data[:], first_offset_extends_b[:]})
	} else {
		earliest_presentation_time := sidx.earliest_presentation_time
		earliest_presentation_time_b := (^[4]byte)(&earliest_presentation_time)^
		data = slice.concatenate([][]byte{data[:], earliest_presentation_time_b[:]})

		first_offset := sidx.first_offset
		first_offset_b := (^[4]byte)(&first_offset)^
		data = slice.concatenate([][]byte{data[:], first_offset_b[:]})
	}

	reserved := sidx.reserved
	reserved_b := (^[2]byte)(&reserved)^
	data = slice.concatenate([][]byte{data[:], reserved_b[:]})

	reference_count := sidx.reference_count
	reference_count_b := (^[2]byte)(&reference_count)^
	data = slice.concatenate([][]byte{data[:], reference_count_b[:]})
	for i := 0; i < int(sidx.reference_count); i += 1 {
		reference_type := sidx.items[i].reference_type
		reference_type_u32be := u32be(reference_type)
		reference_type_u32be = reference_type_u32be
		referenced_size := sidx.items[i].referenced_size
		//referenced_size = (referenced_size << 1)

		tmp := reference_type_u32be | referenced_size
		//tmp = referenced_size
		fmt.println("referenced_size", tmp)
		tmp_b := (^[4]byte)(&tmp)^
		data = slice.concatenate([][]byte{data[:], tmp_b[:]})


		subsegment_duration := sidx.items[i].subsegment_duration
		subsegment_duration_b := (^[4]byte)(&subsegment_duration)^
		data = slice.concatenate([][]byte{data[:], subsegment_duration_b[:]})

		// SAP ---------

		starts_with_SAP := u32be(sidx.items[i].starts_with_SAP) << 31
		fmt.printf("temp_final_b : %b\n", starts_with_SAP)
		SAP_type := u32be(sidx.items[i].SAP_type)
		temp_b := starts_with_SAP | SAP_type
		temp_u32be := u32be(temp_b)
		SAP_delta_time := sidx.items[i].SAP_delta_time
		temp_final := temp_u32be | SAP_delta_time


		temp_final_b := (^[4]byte)(&temp_final)^
		data = slice.concatenate([][]byte{data[:], temp_final_b[:]})
		// starts_with_SAP := sidx.items[i].starts_with_SAP
		// starts_with_SAP_u32 := u32be(starts_with_SAP)
		// //starts_with_SAP_u32 = starts_with_SAP_u32 & 0x00000001
		// SAP_type := sidx.items[i].SAP_type
		// SAP_type_u32be := u32be(SAP_type)
		// SAP_type_u32be = SAP_type_u32be << 1
		// //SAP_type_u32be = SAP_type_u32be & 0x000000FE
		// SAP_delta_time := sidx.items[i].SAP_delta_time
		// SAP_delta_time = SAP_delta_time << 4
		// //tmp = starts_with_SAP_u32 | SAP_type_u32be | SAP_delta_time
		// tmp_b = (^[4]byte)(&tmp)^
		// data = slice.concatenate([][]byte{data[:], tmp_b[:]})

	}
	return data
}
