package mp4


import "core:fmt"
import "core:slice"

Wide :: struct {
	box:            Box,
	unknow_content: []byte,
}

deserialize_wide :: proc(data: []byte) -> (wide: Wide, acc: u64) {
	box, box_size := deserialize_box(data[acc:])
	wide.box = box
	acc += box_size
	size: u64
	if box.size == 1 {
		size = u64(box.largesize)
	} else if box.size == 0 {
		size = u64(len(data))
	} else {
		size = u64(box.size)
	}

	remain := size - acc

	wide.unknow_content = data[acc:acc + remain]

	acc += remain
	fmt.println("acc:", acc)
	return wide, acc
}

serialize_wide :: proc(wide: Wide) -> (data: []byte) {
	box_b := serialize_box(wide.box)
	data = slice.concatenate([][]byte{box_b[:], wide.unknow_content[:]})
	fmt.println("len(data):", len(data))
	return data
}
