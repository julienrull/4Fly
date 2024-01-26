package mp4
import "core:os"
import "core:path/filepath"
import "core:fmt"
import "core:log"
import "core:slice"
import "core:mem"
import "core:strings"


DumpError :: union {
    FileError
}

handle_dump_error :: proc(dump_error: DumpError){
    switch error in dump_error {
        case FileError:
            handle_file_error(error)
    }
}

dump :: proc(file_path: string) -> DumpError {
    handle := fopen(file_path) or_return
    file_size, errno := os.seek(handle, 0, os.SEEK_END)
    os.seek(handle, 0, os.SEEK_SET)
    defer os.close(handle)
    box_b := [32]u8{}
    lvl := 1
    box_size_cumu := 0
    size_heap := [15]u64be{}
    size_heap[1] = u64be(file_size)
    remain_size: u64be = 0
    prev_size: u64be = 0
    prev_box_size: u64be = 0
    boxe_found := false
    for size_heap[1] > 0{
        total_read := fread(handle, box_b[:]) or_return
        box, box_size := deserialize_box(box_b[:])
        type := to_string(&box.type)
        if slice.contains(BOXES, type) {
            size: u64be = 0
            if box.size == 1 {
                size = box.largesize
            //}else if box.size == 0 {
            }else {
                size = u64be(box.size)
            }
            os.seek(handle, -(i64(total_read) - i64(box_size)) , os.SEEK_CUR)
            remain_size = size - u64be(box_size)
            if boxe_found {
                i := lvl
                if prev_size > 8 {
                    for i != 0 {
                        size_heap[i] -= prev_box_size
                        i -= 1
                    }
                    lvl += 1
                    size_heap[lvl] = prev_size - prev_box_size
                }else{
                    size_heap[lvl] -= u64be(box_size)
                }
                boxe_found = false
            }else {
                boxe_found = true
            }
            prev_size = size
            prev_box_size = u64be(box_size)
            print_box_level(type, lvl)
        }else {
            os.seek(handle, i64(remain_size) - i64(total_read), os.SEEK_CUR)
            i := lvl
            for i != 0 {
                size_heap[i] -= prev_size
                if size_heap[i] == 0 {
                    lvl -= 1
                }
                i -= 1
            }
            boxe_found = false
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
                message = "Failed to file.",
                errno = read_errno,
            }
        }
        return total_read, nil
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
	a := [?]string{str, fmt.tprintf("\x1b[1;32m[%s]\x1b[0m", name)}
	str, err = strings.concatenate(a[:])
	fmt.println(str, fmt.tprintf("\x1b[1;33m%d\x1b[0m", level))
}
