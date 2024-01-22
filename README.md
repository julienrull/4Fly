## Table of Content

* [Context](##context)
  * [What is it ?](###what-is-it)
  * [Why is that?](###why-is-that)
* [How to Use ?](##how-to-use?)

## Context

### What is it?

Encoder is a command line tool to fragment on the fly MP4 videos ready for HLS
VOD protocol.
From a source, you can generate HLS Manifest, init file and FMP4 segments
in any order you want.

### Why is that?

I was creating a little streaming services like Plex with GO and Svelte but I struggled with disk spaces as I had to keep two versions of the same video (fragmented and non fragmented) to upload streamable and downloadable videos.
So, I searched for solutions in favor of patial instead of complete fragmentation but I didn't find anything to satisfy my needs, so I done it myself. 

![alt text](demo.gif)

## How to Use?

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

Exemple:


```shell
# Generate HLS Manifest of 6.0 seconds long segments.
encoder.exe .\test.mp4 -time:6.0 -entity:m3u8

# Generate FMP4 init file.
encoder.exe .\test.mp4 -entity:init

# Generate FMP4 20th fragment.
encoder.exe .\test.mp4 -time:6.0 -entity:20 -type:fmp4
```
