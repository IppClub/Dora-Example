# Ogg/Theora video fixtures

`sample.ogv` is the Love project test fixture from
`love2d/love@357b005e5332d7fca847a40eac5b1d263e6e7398`, path
`testing/resources/sample.ogv`. Its SHA-256 is
`53f876beb3d4c583f1b194521f8c91bf05d6cb16a339ecbe603c299b36acd79d`.
It contains Theora video and stereo Vorbis audio.

`sample-no-audio.ogv` is a deterministic video-only derivative produced without
re-encoding:

```sh
ffmpeg -i sample.ogv -map 0:v:0 -c:v copy -an sample-no-audio.ogv
```

Its SHA-256 is
`731d5c5819213abd9b5c9b2943b8143e96c859167017fb13a91f85d62febe66c`.
Both files are committed test inputs; running the test suite does not require
FFmpeg or direct host filesystem access from LoveRuntime.
