package mp4
import "core:os"


select_box :: proc(
	handle: os.Handle,
	box_type: string,
	number: u8 = 1,
) -> (
	box: BoxV2,
	error: FileError,
) {
	os.seek(handle, 0, os.SEEK_CUR) // * Rewind file cursor.
	box_count: u8
	next := next_box(handle, nil) or_return
	atom := get_item_value(next)
	for next != nil {
		if atom.type == box_type {
			box_count += 1
			if box_count == number {
				break
			}
		}
		next = next_box(handle, next) or_return
		atom = get_item_value(next)
	}
	if next == nil {
		// TODO: Error Atom Not Found
	}
	return atom, nil
}
