package mp4
import "core:os"
import "core:path/filepath"
import "core:fmt"
import "core:slice"
import "core:mem"
import "core:strings"


DumpError :: union {
    FileError
}

dump :: proc(file_path: string) -> DumpError {
    handle := fopen(file_path) or_return
    defer os.close(handle)
    box_b := [32]u8{}
    lvl := 0
    box_size_cumu := 0
    size_heap := [100]int{}
    remain_size: i64 = 0
    for true {
        total_read := fread(handle, box_b[:]) or_return
        box, box_size := deserialize_box(box_b[:])
        type := to_string(&box.type)
        if slice.contains(BOXES, type) {
            print_mp4_level(type, lvl)
            size: u64 = 0
            if box.size == 1 {
                size = u64(box.largesize)
            }else if box.size == 0 {

            }else {
                size = u64(box.size)
            }
            os.seek(handle, -(i64(total_read) - i64(box_size)) , os.SEEK_CUR)
            remain_size = i64(size - box_size)
        }else {
            os.seek(handle, remain_size - i64(total_read), os.SEEK_CUR)
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


print_mp4_level :: proc(name: string, level: int) {
	str := ""
	err: mem.Allocator_Error
	i := 0
	for i < level - 1 {
		a := [?]string{str, "-"}
		str, err = strings.concatenate(a[:])
		i = i + 1
	}
	a := [?]string{str, name}
	str, err = strings.concatenate(a[:])
	fmt.println(str, level)
}
//dump :: proc(data: []byte, size: u64, level: int = 0) -> (offset: u64) {
//	lvl := level + 1
//	for offset < size {
//		box, box_size := deserialize_box(data[offset:])
//		type_s := to_string(&box.type)
//		_, ok := BOXES[type_s]
//		if ok {
//			print_mp4_level(type_s, lvl)
//			offset += dump(data[offset + box_size:], u64(box.size) - box_size, lvl) + box_size
//		} else {
//			offset = size
//		}
//	}
//	return offset
//}
