# SPECS

Automatic code formatter for the Odin programming language.

## Requirements

- Written in Odin
- Using package core:odin

## Default style overview:

- tabs for indentation, spaces for alignment
- 1tbs for brace indentation style

## Usage

```shell
> encoder [path] [flags]
```

- path  : mp4 video file system path
- flags :

```
-time:[default = 3.0]
    Segments duration.
-entity:[default=all - values:all;m3u8;init;<segment_number>]
    Entity to generate.
-type:[default=fmp4 - values:fmp4]
    Container's fragments type (fmp4, ts, ...)
```
