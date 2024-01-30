package mp4
import "core:os"


select_box :: proc(handle: os.Handle, box_type: string, number: u8 = 1) -> (aw: AtomWrapper, error: FileError){
    os.seek(handle, 0, os.SEEK_CUR) // * Rewind file cursor.
    box_count: u8
    next := next_atom(handle, nil) or_return
    atom := iterator_value(next)
    for next != nil {
        if atom.type == box_type {
            box_count += 1
            if box_count == number {
                break
            }
        }
        next = next_atom(handle, next) or_return
        atom = iterator_value(next)
    }
    if next == nil {
        // TODO: Error Atom Not Found
    }
    return atom, nil
}
