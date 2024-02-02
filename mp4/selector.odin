package mp4
import "core:os"
import "core:log"


select_box :: proc(
	handle: os.Handle,
	box_type: string,
	number: int = 1,
) -> (
	box: BoxV2,
	error: FileError,
) {
	os.seek(handle, 0, os.SEEK_SET) // * Rewind file cursor.
	box_count: int = 1
	next := next_box(handle, nil) or_return
	atom := get_item_value(next)
	for next != nil {
		if atom.type == box_type {
			if box_count == number {
				break
			}
			box_count += 1
		}
		next = next_box(handle, next) or_return
		atom = get_item_value(next)
	}
	if next == nil {
		// TODO: Error Atom Not Found
	}
	return atom, nil
}
