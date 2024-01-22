![alt text](demo.gif)

Encoder is a command line tool to fragment on the fly MP4 videos ready for HLS
VOD protocol.

> [!CAUTION]
> This project is still in very early stages of development. Use at your own risk.

> [!NOTE]
> We are looking for contributors to help us with this project, especially implementing analyzers for more protocols!!!

## Features

* Satisfy user HLS request, without muxing/demuxing MP4 file, to stream and download videos
    * Manifest (media.m3u8)
    * Initialization file (init.mp4)
    * FMP4 segment (seg-%d.m4s)
* Generate all file with one command
* Dump MP4 files

## Use cases

- Avoid complex processes like multiplexing and demultiplexing
- Save disk space

## Usage

### Build

```
odin build .
```

### Run

```
encoder.exe <path> <flags...>

path  : video path

flags:
    -time:[default = 3.0]
        Segments duration.
    -entity:[default=all - values:all;m3u8;init;<segment_number>]
        Entity to generate.
    -type:[default=fmp4 - values:fmp4]
        Container's fragments type (fmp4, ts, ...)
```

###  Exemples:


```shell
# Generate HLS Manifest of 6.0 seconds long segments.
encoder.exe .\test.mp4 -time:6.0 -entity:m3u8

# Generate FMP4 init file.
encoder.exe .\test.mp4 -entity:init

# Generate FMP4 20th fragment.
encoder.exe .\test.mp4 -time:6.0 -entity:20 -type:fmp4
``` 
