package mp4
import "core:os"
import "core:path/filepath"
import "core:fmt"
import "core:log"
import "core:slice"
import "core:mem"
import "core:strings"
import "core:unicode/utf8"
import "core:c/libc"


BoxError :: union {
    FileError
}

handle_dump_error :: proc(dump_error: BoxError){
    switch error in dump_error {
        case FileError:
            handle_file_error(error)
    }
}


AtomWrapper :: struct {
    header: FullBox,
    type: string,
    total_size: u64be,
    header_size: u64be,
    body_size: u64be,
    is_container: bool,
    position: u64
}

// TODO Is box exist error
read_atom :: proc(handle: os.Handle) -> (aw: AtomWrapper, err: FileError) {
    buffer := [8]u8{}
    total_read := fread(handle, buffer[:]) or_return
    aw.header.box.size = (^u32be)(&buffer[0])^
    aw.header.box.type = (^u32be)(&buffer[4])^
    aw.total_size = u64be(aw.header.box.size)
    aw.type = strings.clone_from_bytes(buffer[4:])
    if aw.header.box.size == 1 {
        total_read += fread(handle, buffer[:]) or_return
        aw.header.box.largesize = (^u64be)(&buffer[0])^
        aw.total_size = aw.header.box.largesize
    }
    //aw.type = to_string(&box.type)
    if aw.type == "uuid" {
        total_read += fread(handle, aw.header.box.usertype[:]) or_return
    }
    aw.header_size = u64be(total_read)
    remain := aw.total_size - aw.header_size
    if remain != 0 {
        if remain >= 8 {
            readed := fread(handle, buffer[:]) or_return
            type_s := strings.clone_from_bytes(buffer[4:])
            if slice.contains(BOXES, type_s) {
                aw.is_container = true
            }
            os.seek(handle, -i64(readed), os.SEEK_CUR)
        }
        if remain >=4 && !aw.is_container {
            total_read += fread(handle, buffer[:4]) or_return
            aw.header.version = buffer[0]
            aw.header.flags[0] = buffer[1]
            aw.header.flags[1] = buffer[2]
            aw.header.flags[2] = buffer[3]
            if aw.type != "ftyp" {
                    aw.header_size += 4
            }
        }
    }
    aw.body_size = aw.total_size - aw.header_size
    os.seek(handle, -i64(total_read), os.SEEK_CUR)
    return aw, err
}

Iterator :: union {
    AtomWrapper,
}

next_atom :: proc(handle: os.Handle, old: Iterator) -> (next: Iterator, err: FileError) {
    switch nature in old {
        case AtomWrapper:
            total_seek: i64 = 0
            if nature.is_container{
                total_seek = fseek(handle, i64(nature.header_size), os.SEEK_CUR) or_return
            }else{
                total_seek = fseek(handle, i64(nature.total_size), os.SEEK_CUR) or_return
            }
            atom, file_error := read_atom(handle)
            if file_error != nil {
                switch nature in file_error {
                    case ReadFileError:
                        if nature.errno ==  38 {
                            return nil, nil
                        }
                        case OpenFileError, SeekFileError, WrongFileTypeError:
                            return next,file_error
                }
            }
            prev_value := iterator_value(old)
            atom.position = prev_value.position + u64(total_seek)
            next = atom
        case nil:
            next = read_atom(handle) or_return
    }
    return next, nil
}

iterator_value :: proc(atom: Iterator) -> (value: AtomWrapper) {
    switch nature in atom {
        case AtomWrapper:
            value = nature
        case nil:
            value = AtomWrapper{}
    }
    return value
}


dump :: proc(file_path: string) -> BoxError {
    handle := fopen(file_path) or_return
    defer os.close(handle)
    file_size := fseek(handle, 0, os.SEEK_END) or_return
    total_seek := fseek(handle, 0, os.SEEK_SET) or_return
    lvl := 1
    size_heap := [15]u64be{}
    size_heap[1] = u64be(file_size)
    next := next_atom(handle, nil) or_return
    for next != nil {
        atom := iterator_value(next)
        print_box_level(atom.type, lvl)
        next = next_atom(handle, next) or_return
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
    handle, open_errno := os.open(clean_file_path, os.O_RDONLY)
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
