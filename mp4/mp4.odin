package mp4

import "core:fmt"
import "core:slice"

Mp4 :: struct {
	ftyp:  Ftyp,
	moov:  Moov,
	styp:  Ftyp,
	sidxs: [dynamic]Sidx,
	moof:  Moof,
	wide:  Wide,
	mdat:  Mdat,
}

deserialize_mp4 :: proc(data: []byte, size: u64) -> (mp4: Mp4, acc: u64) {
	mp4.sidxs = make([dynamic]Sidx, 0, 16)
	sub_box, sub_box_size := deserialize_box(data[acc:])
	name := to_string(&sub_box.type)
	for acc < size {
		switch name {
		case "ftyp":
			atom, atom_size := deserialize_ftype(data[acc:])
			mp4.ftyp = atom
			acc += atom_size
			fmt.println(atom_size)
		case "moov":
			atom, atom_size := deserialize_moov(data[acc:])
			mp4.moov = atom
			acc += atom_size
		case "styp":
			atom, atom_size := deserialize_ftype(data[acc:])
			mp4.styp = atom
			acc += atom_size
		case "sidx":
			atom, atom_size := deserialize_sidx(data[acc:])
			append(&mp4.sidxs, atom)
			acc += atom_size
		case "moof":
			atom, atom_size := deserialize_moof(data[acc:])
			mp4.moof = atom
			acc += atom_size
		case "wide":
			atom, atom_size := deserialize_wide(data[acc:])
			mp4.wide = atom
			acc += atom_size
		case "mdat":
			atom, atom_size := deserialize_mdat(data[acc:])
			mp4.mdat = atom
			acc += atom_size
		// fmt.println(atom_size)
		// fmt.println(atom.box)
		case "free":
			// TODO: free box implementation 
			//atom, atom_size := deserialize_box(data[acc:])
			//mp4.minf = atom
			acc += u64(sub_box.size)
		case:
			panic(fmt.tprintf("mp4 sub box '%v' not implemented", name))
		}
		if acc < size {
			sub_box, sub_box_size = deserialize_box(data[acc:])
			name = to_string(&sub_box.type)
			fmt.println(name)
		}
	}
	return mp4, acc
}

serialize_mp4 :: proc(mp4: Mp4) -> (data: []byte) {
	data = []byte{}
	name := mp4.ftyp.box.type
	if to_string(&name) == "ftyp" {
		bin := serialize_ftype(mp4.ftyp)
		data = slice.concatenate([][]byte{data[:], bin[:]})
	}
	name = mp4.styp.box.type
	if to_string(&name) == "styp" {
		bin := serialize_ftype(mp4.styp)
		data = slice.concatenate([][]byte{data[:], bin[:]})
	}
	name = mp4.moov.box.type
	if to_string(&name) == "moov" {
		bin := serialize_moov(mp4.moov)
		data = slice.concatenate([][]byte{data[:], bin[:]})
	}
	name = mp4.wide.box.type
	if to_string(&name) == "wide" {
		bin := serialize_wide(mp4.wide)
		data = slice.concatenate([][]byte{data[:], bin[:]})
	}
	if len(mp4.sidxs) > 0 {
		for i := 0; i < len(mp4.sidxs); i += 1 {
			bin := serialize_sidx(mp4.sidxs[i])
			data = slice.concatenate([][]byte{data[:], bin[:]})
			fmt.println("len(sidx)", len(bin))
		}
	}
	name = mp4.moof.box.type
	if to_string(&name) == "moof" {
		bin := serialize_moof(mp4.moof)
		data = slice.concatenate([][]byte{data[:], bin[:]})
	}
	name = mp4.mdat.box.type
	if to_string(&name) == "mdat" {
		bin := serialize_mdat(mp4.mdat)
		data = slice.concatenate([][]byte{data[:], bin[:]})
	}
	return data
}
