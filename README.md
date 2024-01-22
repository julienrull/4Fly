# Encoder

## What is it ?

Encoder is a cammand line tool to fragment on the fly MP4 videos ready for HLS
VOD protocol.
From a source, you can generate HLS Manifest, init file and FMP4 segments
in any order you want.

![demo](.\demo.gif "Encoder Demo")

## Why is that?

I was creating a little streaming services like Plex with GO and Svelte but I struggled with disk spaces as I had to keep two versions of the same video (fragmented and non fragmented) to upload streamable and downloadable videos.
So, I searched for solutions in favor of patial instead of complete fragmentation but I didn't find anything to satisfy my needs, so I done it myself. 
