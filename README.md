# 4Fly

> [!warning]
> 4Fly is an exprerimentation, it is an unfinished software. Keep your expectations low. 

4Fly is a cross platform command line tool to demux/encode, at any time , mp4 files into fragments of any duration. It's to attempt avoiding mp4 pre-fragmentation for HLS protocoles.

## Usages

### Fragmentation

```shell
$ 4Fly <path> <flags...>

path  : mp4 video path

flags:
    -time:[default = 3.0]
        fragment duration.
    -entity:[default=all - values:all;m3u8;init;<fragment_number>]
        Entity to generate.
```

*Exemple* :

```shell
# Creating HLS Manifest of 6.0 seconds long segments.
$ 4Fly .\test.mp4 -time:6.0 -entity:m3u8

# Creating FMP4 init file.
$ 4Fly .\test.mp4 -time:6.0 -entity:init

# Creating FMP4 20th fragment.
$ 4Fly .\test.mp4 -time:6.0 -entity:20
```

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

can output something like this :

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

### HLS

To test with HLS protocole :

- Make shure you compile and have 4Fly binary in project root.
- Go to "server" folder
- Put your video in
- Rename the video to "test.mp4"
- Run :

```go
$ go run .
```

- Open your browser to [http://localhost:8080](http://localhost:8080)
  
  

... And that's it !

## Installation

### Binary file

You can download the laste version here.

### Compile from sources

From Windows, Linux or MacOS:

- Get odin compiler, you need the "core" library.

- Clone 4File main branch and build
  
  ```bash
  git clone https://github.com/julienrull/4Fly.git
  cd 4Fly
  odin build .
  ```
