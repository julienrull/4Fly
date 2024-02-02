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

write_fragment :: proc(handle: os.Handle) -> FileError {
    fragment_number := 1
    fragment_duration := 3.7
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
    write_ftyp(output, styp) or_return

    // sidx
    // moof
    // mfhd
    //mdhd_vide := read_mdhd(handle, vide_id) or_return
    //mdhd_soun := read_mdhd(handle, soun_id) or_return
    //hdlr_vide := read_hdlr(handle, vide_id) or_return
    //hdlr_soun := read_hdlr(handle, soun_id) or_return
    //stts_vide := read_stts(handle, vide_id) or_return
    //stts_soun := read_stts(handle, soun_id) or_return
    //stsc_vide := read_stsc(handle, vide_id) or_return
    //stsc_soun := read_stsc(handle, soun_id) or_return
    //stco_vide := read_stco(handle, vide_id) or_return
    //stco_soun := read_stco(handle, soun_id) or_return
    //co64_vide := read_co64(handle, vide_id) or_return
    //co64_soun := read_co64(handle, soun_id) or_return
    //stsz_vide := read_stsz(handle, vide_id) or_return
    //stsz_soun := read_stsz(handle, soun_id) or_return

    return nil
}
