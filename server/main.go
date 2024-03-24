package main
import "fmt"
import "log"
import "strings"
import "strconv"
import "path"
import "path/filepath"
import "os"
import "os/exec"
import "regexp"
import "net/http"

type FSHandler = func(w http.ResponseWriter, r *http.Request) (doDefaultFileServe bool)


func CustomFileServer(root http.FileSystem) http.Handler {
    EXE := "../4Fly"
	fs := http.FileServer(root)
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		//make sure the url path starts with /
		upath := r.URL.Path
		if !strings.HasPrefix(upath, "/") {
			upath = "/" + upath
			r.URL.Path = upath
		}
		upath = path.Clean(upath)
        ext := filepath.Ext(upath)
		// attempt to open the file via the http.FileSystem
		f, err := root.Open(upath)
		if err != nil {
			if os.IsNotExist(err) {
                // Get path file extension
                file_name := filepath.Base(upath)
                // check extension
                if ext == ".m3u8" {
                    // call encoder
                    cmd := exec.Command(EXE, "./test.mp4", "-entity:m3u8", "-time:3.0")
                    err := cmd.Run()
                    fmt.Println(ext)
                    if err != nil {
                        log.Fatal(err)
                    }      
                }else if ext == ".mp4" {
                    cmd := exec.Command(EXE, "./test.mp4", "-entity:init", "-time:3.0")
                    err := cmd.Run()
                    fmt.Println(ext)
                    if err != nil {
                        log.Fatal(err)
                    }      
                }else if ext == ".m4s" {
                    re := regexp.MustCompile("[0-9]+")
                    res := re.FindAllString(file_name, -1)
                    value, _ := strconv.Atoi(res[0])
                    cmd := exec.Command(EXE, "./test.mp4", fmt.Sprintf("-entity:%d", value), "-time:3.0")
                    err := cmd.Run()
                    if err != nil {
                        log.Fatal(err)
                    }      
                }
			}
		}else{
            f.Close()
        }
		// default serve
		fs.ServeHTTP(w, r)
        rm_err := os.Remove("./"+upath[1:])
        if rm_err != nil {
            fmt.Println(rm_err)
        }
	})
}

func main() {
    http.Handle("/", http.StripPrefix("/", CustomFileServer(http.Dir("./"))))
    fmt.Printf("Starting server at port 8080\n")
    if err := http.ListenAndServe(":8080", nil); err != nil {
        log.Fatal(err)
    }
}
