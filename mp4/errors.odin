package mp4
import "core:os"

//  ### FILE ERRORS
FileError           :: union {
    OpenFileError,
    ReadFileError,
    WrongFileError
}
OpenFileError       :: struct {
    path:       string,
    errno:      os.Errno,
}
ReadFileError       :: struct {
    message:    string,
    errno:      os.Errno,
}
WrongFileError      :: struct {}
//  ###

//  ### BOX ERRORS
BoxError            :: union {
    UnknowBoxError
}
UnknowBoxError      :: struct {}

