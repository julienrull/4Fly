![logo](https://miro.medium.com/v2/resize:fit:1400/1*lq1UoerfrNwqxwUW84-ihg.jpeg)

> [!warning]
> This software is unfinished. Keep your expectations low.
> It will not works with all mp4 files.

> [!info]
> I created this tool on my free time. It becames too long for a personal project, so it's  in stand by for now.

4Fly is a command line tool to generate, on the fly, any part of a mp4 file as mp4 fragment with hls protocol compliance .

## Installation

### Binary file
You can download the laste version here.

### Compile from sources

From Windows, Linux or MacOS:

- Get odin compiler, you will need the "core" library.
- Clone the main branch.
- Get to the root of the project.
- Run :

```shell
$ odin build .
```

## Usages
### Dump
You can display the file structure :
```shell
$ 4Fly dump <mp4_file_path> 
```

*Exemple*: 

Run this :

```
$ 4Fly dump test.mp4
```

will output :

```shell
[ftyp]  0
[moov]  0
| [mvhd]  1
| [trak]  1
| | [tkhd]  2
| | [edts]  2
| | | [elst]  3
| | [mdia]  2
| | | [mdhd]  3
| | | [hdlr]  3
| | | [minf]  3
| | | | [vmhd]  4
| | | | [dinf]  4
| | | | | [dref]  5
| | | | [stbl]  4
| | | | | [stsd]  5
| | | | | [stts]  5
| | | | | [stss]  5
| | | | | [ctts]  5
| | | | | [stsc]  5
| | | | | [stsz]  5
| | | | | [co64]  5
| [trak]  1
| | [tkhd]  2
| | [edts]  2
| | | [elst]  3
| | [mdia]  2
| | | [mdhd]  3
| | | [hdlr]  3
| | | [minf]  3
| | | | [smhd]  4
| | | | [dinf]  4
| | | | | [dref]  5
| | | | [stbl]  4
| | | | | [stsd]  5
| | | | | [stts]  5
| | | | | [stsc]  5
| | | | | [stsz]  5
| | | | | [co64]  5
| [udta]  1
| | [meta]  2
[mdat]
```

### Fragmentation

```shell
$ 4Fly <path> <flags...>

path  : mp4 video path

flags:
    -time:[default = 3.0]
        Segments duration.
    -entity:[default=all - values:all;m3u8;init;<segment_number>]
        Entity to generate.
```

*Exemple* : 

```shell
# Generate HLS Manifest of 6.0 seconds long segments.
$ 4Fly .\test.mp4 -time:6.0 -entity:m3u8

# Generate FMP4 init file.
$ 4Fly .\test.mp4 -time:6.0 -entity:init

# Generate FMP4 20th fragment.
$ 4Fly .\test.mp4 -time:6.0 -entity:20
```

### With http server

Here is an exemple to show you the main usage of 4Fly.
Here you can run a test server with go that going to serve your video with hls protocole without the need to pre-fragment your video.

To run it :

- Make shure you compile and have 4Fly located in project root.
- Go to "server" folder
- Put your video in
- Rename the video to "test.mp4"
- Run :

```go
$ go run .
```

- Open your browser
- Go to url "http://localhost:8080"

... And that's it !

