package mp4

import "core:slice"
import "core:mem"

// ChunkOffsetBox
Stco :: struct {
    fullbox: FullBox,
    entry_count: u32be,
    chunks_offsets: []u32be
}

// ChunkLargeOffsetBox
Co64 :: struct {
    fullbox: FullBox,
    entry_count: u32be,
    chunks_offsets: []u64be
}

deserialize_stco :: proc(data: []byte) -> (stco: Stco, acc: u64) {
    fullbox, fullbox_size :=  deserialize_fullbox(data[acc:])
    acc += fullbox_size
    stco.entry_count = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    stco.chunks_offsets = make([]u32be, stco.entry_count)
    for i:=0; i<int(stco.entry_count); i+=1 {
        stco.chunks_offsets[i] = (^u32be)(&data[acc])^
        acc += size_of(u32be)
    }
    return stco, acc
}

deserialize_co64 :: proc(data: []byte) -> (co64: Co64, acc: u64) {
    fullbox, fullbox_size :=  deserialize_fullbox(data[acc:])
    acc += fullbox_size
    co64.entry_count = (^u32be)(&data[acc])^
    acc += size_of(u32be)
    co64.chunks_offsets = make([]u64be, co64.entry_count)
    for i:=0; i<int(co64.entry_count); i+=1 {
        co64.chunks_offsets[i] = (^u64be)(&data[acc])^
        acc += size_of(u32be)
    }
    return co64, acc
}

serialize_stco :: proc(stco: Stco) -> (data: []byte) {
    fullbox_b := serialize_fullbox(stco.fullbox)
    entry_count := stco.entry_count
    entry_count_b := (^[4]byte)(&entry_count)^
    data = slice.concatenate([][]byte{fullbox_b[:], entry_count_b[:]})
    if entry_count > 0 {
        chunks_offsets := stco.chunks_offsets[:]
        chunks_offsets_b := mem.ptr_to_bytes(&chunks_offsets, size_of(u32be) * int(entry_count))
        data = slice.concatenate([][]byte{data[:], chunks_offsets_b[:]})
    }
    return data
}

serialize_co64 :: proc(co64: Co64) -> (data: []byte) {
    fullbox_b := serialize_fullbox(co64.fullbox)
    entry_count := co64.entry_count
    entry_count_b := (^[4]byte)(&entry_count)^
    data = slice.concatenate([][]byte{fullbox_b[:], entry_count_b[:]})
    if entry_count > 0 {
        chunks_offsets := co64.chunks_offsets[:]
        chunks_offsets_b := mem.ptr_to_bytes(&chunks_offsets, size_of(u64be) * int(entry_count))
        data = slice.concatenate([][]byte{data[:], chunks_offsets_b[:]})
    }
    return data
}