package mp4
import "core:os"
import "core:log"

//  ### FILE ERRORS
FileError           :: union {
    OpenFileError,
    ReadFileError,
    WrongFileTypeError
}

handle_file_error :: proc (error: FileError) {
    switch nature in error {
        case OpenFileError:
            handle_open_file_error(nature)
        case ReadFileError:
            handle_read_file_error(nature)
        case WrongFileTypeError:
    }
}

OpenFileError       :: struct {
    path:       string,
    errno:      os.Errno,
}
handle_open_file_error :: proc(error: OpenFileError) {
    if error.errno == 2 {
        log.errorf("errno %d: ERROR_FILE_NOT_FOUND", error.errno)
    }else {
        log.errorf("errno %d: UNKNOW_OPEN_FILE_ERROR", error.errno)
    }
}
ReadFileError       :: struct {
    message:    string,
    errno:      os.Errno,
    handle: os.Handle
}
handle_read_file_error :: proc(error: ReadFileError) {
    if error.errno == 1 || error.errno == 21 {
        log.errorf("errno %d: ERROR_FILE_IS_NOT_DIR", error.errno)
    }else if error.errno == 38 {
        log.errorf("errno %d: ERROR_EOF", error.errno)
    }else {
        log.errorf("errno %d: UNKNOW_READ_FILE_ERROR", error.errno)
    }
    os.close(error.handle)
}
WrongFileTypeError      :: struct {}
//  ###

//  ### BOX ERRORS
BoxError            :: union {
    UnknowBoxError
}
UnknowBoxError      :: struct {}

