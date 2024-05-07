# LocalVideoStreaming

Sample code for streaming video between iOS, macOS, or visionOS devices.

This is not a drop in solution for video streaming and will not compile on its own, but hopefully acts as a reference for how apps like [Detail](https://apps.apple.com/us/app/detail-video-studio/id1673518618), [Castaway](https://apps.apple.com/app/apple-store/id6476697957), [Bezel](https://apps.apple.com/us/app/bezel-device-mirror/id6476657945), [Splitscreen](https://apps.apple.com/us/app/splitscreen-multi-display/id6478007837), and [Final Cut Camera](https://www.apple.com/newsroom/2024/05/final-cut-pro-transforms-video-creation-with-live-multicam-on-ipad-and-new-ai-features-on-mac/) are able to connect and stream realtime video across devices.

The `RealtimeStreaming` package provides generic local p2p connectivity similar to [Multipeer Connectivity](https://developer.apple.com/documentation/multipeerconnectivity), while the `Networking` class incorporates the [Transcoding](https://github.com/finnvoor/Transcoding) package for local video streaming.
