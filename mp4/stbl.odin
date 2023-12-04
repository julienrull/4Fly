package mp4

import "core:fmt"
import "core:slice"

// SampleTableBox
Stbl :: struct {
	// minf -> stbl
	box:  Box,
	stts: Stts,
	ctts: Ctts,
	stsd: Stsd,
	stsz: Stsz,
	stz2: Stz2,
	stsc: Stsc,
	stco: Stco,
	co64: Co64,
	stss: Stss,
	stsh: Stsh,
	stdp: Stdp,
	padb: Padb,
	sbgp: Sbgp,
	sgpd: Sgpd
}

deserialize_stbl :: proc(data: []byte, handle_type: u32be) -> (stbl: Stbl, acc: u64) {
	box, box_size := deserialize_box(data)
	stbl.box = box
	acc += box_size
	size: u64
    if box.size == 1 {
        size = u64(box.largesize)
    }else if box.size == 0 {
        size = u64(len(data))
    }else {
        size =  u64(box.size)
    }
	sub_box, sub_box_size := deserialize_box(data[acc:])
	name := to_string(&sub_box.type)
	for acc < size {
		switch name {
		case "stts":
			atom, atom_size := deserialize_stts(data[acc:])
			stbl.stts = atom
			acc += atom_size
		case "ctts":
			atom, atom_size := deserialize_ctts(data[acc:])
			stbl.ctts = atom
			acc += atom_size
		case "stsd":
			atom, atom_size := deserialize_stsd(data[acc:], handle_type)
			stbl.stsd = atom
			acc += atom_size
		case "stsz":
			atom, atom_size := deserialize_stsz(data[acc:])
			stbl.stsz = atom
			acc += atom_size
		case "stz2":
			atom, atom_size := deserialize_stz2(data[acc:])
			stbl.stz2 = atom
			acc += atom_size
		case "stsc":
			atom, atom_size := deserialize_stsc(data[acc:])
			stbl.stsc = atom
			acc += atom_size
		case "stco":
			atom, atom_size := deserialize_stco(data[acc:])
			stbl.stco = atom
			acc += atom_size
		case "co64":
			atom, atom_size := deserialize_co64(data[acc:])
			stbl.co64 = atom
			acc += atom_size
		case "stss":
			atom, atom_size := deserialize_stss(data[acc:])
			stbl.stss = atom
			acc += atom_size
		case "stsh":
			atom, atom_size := deserialize_stsh(data[acc:])
			stbl.stsh = atom
			acc += atom_size
		case "stdp":
			atom, atom_size := deserialize_stdp(data[acc:], stbl.stsz.sample_count)
			stbl.stdp = atom
			acc += atom_size
		case "padb":
			atom, atom_size := deserialize_padb(data[acc:])
			stbl.padb = atom
			acc += atom_size
		case "sbgp":
			atom, atom_size := deserialize_sbgp(data[acc:])
			stbl.sbgp = atom
			acc += atom_size
		case "sgpd":
			atom, atom_size := deserialize_sgpd(data[acc:], handle_type)
			stbl.sgpd = atom
			acc += atom_size
		case:
			panic(fmt.tprintf("stbl sub box '%v' not implemented", name))
		}
		if acc < size {
            sub_box, sub_box_size = deserialize_box(data[acc:])
            name = to_string(&sub_box.type)
        }
	}
	return stbl, acc
}

serialize_stbl :: proc(stbl: Stbl, handle_type: u32be) -> (data: []byte) {
	box_b := serialize_box(stbl.box)
	data =  box_b[:]
	name := stbl.stts.fullbox.box.type
	name_s := to_string(&name)
	if name_s == "stts" {
		bin := serialize_stts(stbl.stts)
		data = slice.concatenate([][]byte{data[:], bin[:]})
	}
	name = stbl.ctts.fullbox.box.type
	name_s = to_string(&name)
	if name_s == "ctts" {
		bin := serialize_ctts(stbl.ctts)
		data = slice.concatenate([][]byte{data[:], bin[:]})
	}
	name = stbl.stsd.fullbox.box.type
	name_s = to_string(&name)
	if name_s == "stsd" {
		bin := serialize_stsd(stbl.stsd, handle_type)
		data = slice.concatenate([][]byte{data[:], bin[:]})
	}
	name = stbl.stsz.fullbox.box.type
	name_s = to_string(&name)
	if name_s == "stsz" {
		bin := serialize_stsz(stbl.stsz)
		data = slice.concatenate([][]byte{data[:], bin[:]})
	}
	name = stbl.stz2.fullbox.box.type
	name_s = to_string(&name)
	if name_s == "stz2" {
		bin := serialize_stz2(stbl.stz2)
		data = slice.concatenate([][]byte{data[:], bin[:]})
	}
	name = stbl.stsc.fullbox.box.type
	name_s = to_string(&name)
	if name_s == "stsc" {
		bin := serialize_stsc(stbl.stsc)
		data = slice.concatenate([][]byte{data[:], bin[:]})
	}
	name = stbl.stco.fullbox.box.type
	name_s = to_string(&name)
	if name_s == "stco" {
		bin := serialize_stco(stbl.stco)
		data = slice.concatenate([][]byte{data[:], bin[:]})
	}
	name = stbl.co64.fullbox.box.type
	name_s = to_string(&name)
	if name_s == "co64" {
		bin := serialize_co64(stbl.co64)
		data = slice.concatenate([][]byte{data[:], bin[:]})
	}
	name = stbl.stss.fullbox.box.type
	name_s = to_string(&name)
	if name_s == "stss" {
		bin := serialize_stss(stbl.stss)
		data = slice.concatenate([][]byte{data[:], bin[:]})
	}
	name = stbl.stsh.fullbox.box.type
	name_s = to_string(&name)
	if name_s == "stsh" {
		bin := serialize_stsh(stbl.stsh)
		data = slice.concatenate([][]byte{data[:], bin[:]})
	}
	name = stbl.stdp.fullbox.box.type
	name_s = to_string(&name)
	if name_s == "stdp" {
		bin := serialize_stdp(stbl.stdp, stbl.stsz.sample_count)
		data = slice.concatenate([][]byte{data[:], bin[:]})
	}
	name = stbl.padb.fullbox.box.type
	name_s = to_string(&name)
	if name_s == "padb" {
		bin := serialize_padb(stbl.padb)
		data = slice.concatenate([][]byte{data[:], bin[:]})

	}
	name = stbl.sbgp.fullbox.box.type
	name_s = to_string(&name)
	if name_s == "sbgp" {
		bin := serialize_sbgp(stbl.sbgp)
		data = slice.concatenate([][]byte{data[:], bin[:]})
		fmt.println("len(sbgp)", len(bin))
	}
	name = stbl.sgpd.fullbox.box.type
	name_s = to_string(&name)
	if name_s == "sgpd" {
	    bin := serialize_sgpd(stbl.sgpd, handle_type)
	    data = slice.concatenate([][]byte{data[:], bin[:]})
	}
	return data
}
