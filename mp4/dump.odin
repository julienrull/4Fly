package mp4
import "core:os"
import "core:path/filepath"
import "core:fmt"
import "core:log"
import "core:slice"
import "core:mem"
import "core:strings"
import "core:bytes"


BoxError :: union {
    FileError
}

handle_dump_error :: proc(dump_error: BoxError){
    switch error in dump_error {
        case FileError:
            handle_file_error(error)
    }
}



// TODO Is box exist error

Item :: union {
    BoxV2,
}

next_box :: proc(handle: os.Handle, old: Item) -> (next: Item, err: FileError) {
    switch nature in old {
        case BoxV2:
            total_seek: i64 = 0
            if nature.is_container{
                total_seek = fseek(handle, i64(nature.header_size), os.SEEK_CUR) or_return
            }else{
                total_seek = fseek(handle, i64(nature.total_size), os.SEEK_CUR) or_return
            }
            box, file_error := read_box(handle)
            if file_error != nil {
                switch nature in file_error {
                    case ReadFileError:
                        if nature.errno ==  38 {
                            return nil, nil
                        }
                        case WriteFileError, OpenFileError, SeekFileError, WrongFileTypeError:
                            return next,file_error
                }
            }
            prev_value := get_item_value(old)
            box.position = prev_value.position + u64(total_seek)
            next = box
        case nil:
            next = read_box(handle) or_return
    }
    return next, nil
}

get_item_value :: proc(item: Item) -> (value: BoxV2) {
    switch nature in item {
        case BoxV2:
            value = nature
        case nil:
            value = BoxV2{}
    }
    return value
}


dump :: proc(handle: os.Handle) -> FileError {
    fseek(handle, 0, os.SEEK_SET) or_return
    file_size := fseek(handle, 0, os.SEEK_END) or_return
    fseek(handle, 0, os.SEEK_SET) or_return
    lvl := 1
    size_heap := [15]u64be{}
    size_heap[1] = u64be(file_size)
    next := next_box(handle, nil) or_return
    for next != nil {
        atom := get_item_value(next)
        print_box_level(atom.type, lvl)
        next = next_box(handle, next) or_return
        i := lvl
        for i != 0 {
            if atom.is_container {
                size_heap[i] -= atom.header_size
            }else {
                size_heap[i] -= atom.total_size
            }
            i -= 1
        }
        i = lvl
        for i != 0 {
            if size_heap[i] == 0 {
                lvl -= 1
            }
            i -= 1
        }
        if atom.is_container {
            lvl += 1
            size_heap[lvl] = atom.body_size
        }
        // TODO EOF not working on linux
        if lvl == 0 {
            next = nil
        }
    }
    return nil
}


fopen :: proc(path: string, mode: int = os.O_RDONLY, perm: int = 0)  -> (os.Handle, FileError) {
    clean_file_path := filepath.clean(path)
    handle, open_errno := os.open(clean_file_path, mode, perm)
    if open_errno !=  os.ERROR_NONE {
        return os.Handle{}, OpenFileError {
            path = path,
            errno = open_errno,
        }
    }
    return handle, nil
}

fread :: proc(handle: os.Handle, buffer: []u8) -> (int, FileError) {
        total_read, read_errno := os.read(handle, buffer)
        if read_errno !=  os.ERROR_NONE {
            return 0 , ReadFileError {
                message = "Reading failed.",
                errno = read_errno,
                handle = handle,
            }
        }
        return total_read, nil
}

fseek :: proc(handle: os.Handle, offset: i64, whence: int) -> (i64, FileError) {
        total_seek, seek_errno := os.seek(handle, offset, whence)
        if seek_errno != os.ERROR_NONE {
            return 0 , SeekFileError {
                message = "Seeking faild.",
                errno = seek_errno,
                handle = handle,
            }
        }
        return total_seek, nil
}

fwrite :: proc(handle: os.Handle, data: []u8) -> (int, FileError) {
    total_write, write_errno := os.write(handle, data)
    if write_errno != os.ERROR_NONE {
        return 0 , WriteFileError {
            message = "Writing faild.",
            errno = write_errno,
            handle = handle,
        }
    }
    return total_write, nil
}

print_box_level :: proc(name: string, level: int) {
	str := ""
	err: mem.Allocator_Error
	i := 0
	for i < level - 1 {
		a := [?]string{str, "| "}
		str, err = strings.concatenate(a[:])
		i = i + 1
	}
	a := [?]string{str, fmt.tprintf("\x1b[1;32m[%s] \x1b[0m", name)}
	str, err = strings.concatenate(a[:])
	fmt.println(str, fmt.tprintf("\x1b[1;33m%d\x1b[0m", level - 1))
}
