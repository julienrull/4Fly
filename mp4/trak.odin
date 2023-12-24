package mp4

import "core:fmt"
import "core:slice"

// TrackBox
Trak :: struct {
	// moov -> trak
	box:  Box,
	tkhd: Tkhd,
	edts: Edts,
	mdia: Mdia,
}

deserialize_trak :: proc(data: []byte) -> (trak: Trak, acc: u64) {
	box, box_size := deserialize_box(data)
	trak.box = box
	acc += box_size
	size: u64
	if box.size == 1 {
		size = u64(box.largesize)
	} else if box.size == 0 {
		size = u64(len(data))
	} else {
		size = u64(box.size)
	}
	sub_box, sub_box_size := deserialize_box(data[acc:])
	name := to_string(&sub_box.type)
	for acc < size {
		switch name {
		case "tkhd":
			atom, atom_size := deserialize_tkhd(data[acc:])
			trak.tkhd = atom
			acc += atom_size
		// fmt.println("name", name)
		// fmt.println("atom.size", atom.fullbox.box.size)
		// fmt.println("atom_size", atom_size)
		// fmt.println(atom)
		case "edts":
			atom, atom_size := deserialize_edts(data[acc:])
			trak.edts = atom
			acc += atom_size
		case "mdia":
			atom, atom_size := deserialize_mdia(data[acc:])
			trak.mdia = atom
			acc += atom_size
		case "udta":
			// atom, atom_size := deserialize_mdia(data[acc:])
			// trak.mdia = atom
			// acc += atom_size
			acc += u64(sub_box.size)
		case:
			panic(fmt.tprintf("trak sub box '%v' not implemented", name))
		}
		if acc < size {
			sub_box, sub_box_size = deserialize_box(data[acc:])
			name = to_string(&sub_box.type)
		}
	}
	return trak, acc
}

serialize_trak :: proc(trak: Trak) -> (data: []byte) {
	box_b := serialize_box(trak.box)
	data = slice.concatenate([][]byte{[]byte{}, box_b[:]})
	name := trak.tkhd.fullbox.box.type
	if to_string(&name) == "tkhd" {
		bin := serialize_tkhd(trak.tkhd)
		data = slice.concatenate([][]byte{data[:], bin[:]})
	}
	name = trak.edts.box.type
	if to_string(&name) == "edts" {
		bin := serialize_edts(trak.edts)
		data = slice.concatenate([][]byte{data[:], bin[:]})
	}
	name = trak.mdia.box.type
	if to_string(&name) == "mdia" {
		bin := serialize_mdia(trak.mdia)
		data = slice.concatenate([][]byte{data[:], bin[:]})
	}
	return data
}
