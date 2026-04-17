---
layout: post
title: "Live Camera Face Detection in .NET MAUI"
description: "How to use SkiaCamera with AI/ML locally and with an API"
date: 2026-04-11 12:00:00 +0000
categories: [MAUI, DrawnUI, Camera, AI]
tags: [dotnetmaui, skiasharp, camera, mediapipe, facedetection, drawnui, ml, mediapipe]
image: /assets/img/facedetect1.jpg
---

## Intro

Mobile and desktop devices can detect almost anything in images today, starting with QR codes and ending with the number of calories in displayed food. There are many ways to do this on platforms supported by **.NET MAUI**. Various local ML engines such as **TensorFlow Lite**, native platform-only SDKs like **ARKit** for iOS, or remote vision API endpoints, either custom or provided by giants of the AI market, can all play a role. It is all up to your app architecture and implementation.

When it comes to capturing these images from a live camera feed, the `DrawnUi.Maui.Camera` NuGet package is a good choice. In our [previous article](../VideoRecording/) we already showed how to use `SkiaCamera` to send real-time audio to AI. Today we will use it for **live face detection**.

Let's set up **MediaPipe** local face landmark detection from the live preview of `SkiaCamera`. I chose `MediaPipe` for maximum possible cross-platform consistency. The sample app, [DetectFaces](https://github.com/taublast/DetectFaces), is open source and runs the same way on **iOS, Android, and Windows**.

The app also draws overlays directly onto the Skia canvas and makes face masks stick to moving heads at camera frame rate.

<!-- Funny hat screenshot here -->

You can inspect the open-source code to see how it was wired with `MediaPipe`. We will not talk about the specific app in detail; it is included as example source code. Our goal today is to show **how to use live video frames for AI/ML locally and with an API**.

## The Plug

When `SkiaCamera` runs a live preview, the images you see on the screen remain on GPU-backed surfaces during the processing flow. We need to extract images, and at a suitable size, into CPU memory so we can use them safely outside the camera flow. For that we can override the AI-ready `OnRawFrameAvailable(RawCameraFrame frame)` method. This callback fires on every camera frame before the frame goes to processing, so here we get the raw data before other code applies filter effects or overlays to it.

The received struct `RawCameraFrame` holds a GPU-backed SkImage along with some metadata. The image can be of preview size when not recording, can be a huge high-resolution frame if we are in the middle of video recording, or in some cases can even be `null`.

When `OnRawFrameAvailable` hits, we are inside a GPU processing thread. We should never do any heavy work here, but we can execute fast rescaling methods that read from GPU surfaces and provide the payloads we need for AI/ML use decoupled from this thread.

## For Local ML

The received `RawCameraFrame frame` exposes a `frame.TryGetRgba(width, height, buffer)`, which fills a pre-allocated `byte[]` with display-oriented RGBA pixels at the size you want for inference. That is the path the sample uses. It avoids per-frame image allocation, keeps the API consistent across platforms, and still works on zero-copy GPU paths where there may not even be a usable `SKImage` instance to hand out.

It also carries a few bits of metadata:

- `frame.SourceWidth` / `frame.SourceHeight` tell us the size of the incoming camera frame before resizing
- `frame.Rotation` tells us how much extra rotation would be needed if we decide to use the raw image directly
- `frame.RawImage` is optional advanced access only, valid only inside the callback, and may be `null` on some GPU-backed paths

Even for local ML, the safest default is to drop frames while the detector is still working, applies not only to faces, but also to QR scanning, OCR, lightweight object detection, classification, or any model that runs continuously over live preview. It is better to skip frames than to make the preview lag.

```csharp
private readonly byte[] _rgbaBuffer = new byte[targetWidth * targetHeight * 4];
private readonly SemaphoreSlim _detectorBusy = new(1, 1);

protected override void OnRawFrameAvailable(RawCameraFrame frame)
{
    if (!_detectorBusy.Wait(0))
        return;

    if (!frame.TryGetRgba(targetWidth, targetHeight, _rgbaBuffer))
    {
        _detectorBusy.Release();
        return;
    }

    var snapshot = _rgbaBuffer.ToArray();

    _ = Task.Run(async () =>
    {
        try
        {
            await detector.EnqueueDetectionAsync(snapshot, request);
        }
        finally
        {
            _detectorBusy.Release();
        }
    });
}
```

Sample app has a bit different code. It avoids per-frame allocations by reusing multiple buffers and handing buffer ownership across the pipeline, so the above code is rather an illustration for: no camera-thread blocking, no unbounded queue, and explicit frame dropping while work is already in flight. 

The following code is more optimized: it replaces the `ToArray()` snapshot with a small reusable buffer pool and submits work into a detector-owned pipeline instead of wrapping that handoff in another `Task.Run`:

```csharp
private readonly byte[][] _mlBuffers =
[
    new byte[targetWidth * targetHeight * 4],
    new byte[targetWidth * targetHeight * 4]
];
private readonly object _detectionSync = new();
private int _activeBufferIndex = -1;
private DetectionWorkItem? _queuedDetectionWorkItem;

protected override void OnRawFrameAvailable(RawCameraFrame frame)
{
    DetectionWorkItem? workItemToSubmit = null;

    lock (_detectionSync)
    {
        int writeBufferIndex = _activeBufferIndex == 0 ? 1 : 0;

        if (!frame.TryGetRgba(targetWidth, targetHeight, _mlBuffers[writeBufferIndex]))
            return;

        var workItem = new DetectionWorkItem(
            writeBufferIndex,
            targetWidth,
            targetHeight,
            frame.Rotation);

        if (_activeBufferIndex >= 0)
        {
            _queuedDetectionWorkItem = workItem;
            return;
        }

        _activeBufferIndex = workItem.BufferIndex;
        workItemToSubmit = workItem;
    }

    detectionPipeline.Submit(workItemToSubmit);
}
```

Detector already owns the background pipeline here, `OnRawFrameAvailable(...)` only prepares the frame and decides whether to drop or queue it, then hands the request off. Completion callbacks would later release the active buffer and, if needed, submit the newest queued frame.

## For Remote API

Our sample app uses local ML, but the same raw-frame hook would be used if we wanted to send frames to some hosted AI API.

For performance reasons we should not try to upload every preview frame, but, for example, allow one send at most every 300 ms, and also skip sending frames until the previous request has returned. 

For public LLM vision APIs I would send JPEG or PNG, not raw RGBA bytes:

```csharp
private const int RemoteUploadIntervalMs = 300;
private long _lastUploadStartedAtMs;
private readonly SemaphoreSlim _uploadGate = new(1, 1);

protected override void OnRawFrameAvailable(RawCameraFrame frame)
{
    long nowMs = Environment.TickCount64;
    if (nowMs - Volatile.Read(ref _lastUploadStartedAtMs) < RemoteUploadIntervalMs)
        return;

    if (!_uploadGate.Wait(0))
        return;

    if (!frame.TryGetJpeg(targetWidth, targetHeight, out var payload, 100))
    {
        _uploadGate.Release();
        return;
    }

    Volatile.Write(ref _lastUploadStartedAtMs, nowMs);

    _ = Task.Run(async () =>
    {
        try
        {
            await apiClient.UploadImageAsync(payload, "image/jpeg");
        }
        finally
        {
            _uploadGate.Release();
        }
    });
}
```

`SemaphoreSlim.Wait(0)` is doing the neat part here: it never blocks the camera callback, but it also guarantees that only one upload can be in flight at a time. The 300 ms timestamp gate handles the minimum delay between sends. If the network call takes longer than 300 ms, the in-flight gate wins and newer frames are skipped.

`TryGetJpeg(...)` or `TryGetPng(...)` return a standard encoded image payload that public APIs can usually accept directly.

For custom endpoints that expect raw `RGBA8888` data you can use `TryGetRgbaBytes(...)` .
 
## Sample App

Feel free to play with this MediaPipe Tasks example and dig into the source code and also check the included docs: `Implementation.md` helps explain the architecture, and `Includes.md` explains how tML models are included inside the app for each platform. Normally one could customize the same setup to include other models and detect different kinds of things.

### What Else Can You Detect

The architecture - `MediaPipeTasksVision` on mobile, `Mediapipe.Net` TFLite graphs on Windows - generalizes to other tasks by swapping the model file and parsing different output structures:

- **Hand landmarks** (`hand_landmarker.task`) - 21 3D joint points per hand, gesture control, sign language
- **Pose landmarks** (`pose_landmarker.task`) - 33 body joints, fitness tracking, motion capture
- **Object detection** (`efficientdet.task`) - bounding boxes with class labels
- **Image segmentation** (`image_segmenter.task`) - per-pixel foreground/background separation (the Zoom background blur mechanism)
- **Image classification** - whole-image category labels

The hard parts - unmanaged memory safety on Windows, async frame queue, landmark smoothing - are already solved in the sample. Adding a new task is mostly parsing a different output.

## Final Thoughts

Sending frames from a camera to a local ML model, with results drawn back at preview framerate, is surprisingly approachable once the async queue and scaling are handled. The performance numbers in the status bar of the sample app (resize time, inference time, frame dimensions, cpu/gpu) make it easy to tune for your target device.

If you build something with this - a game, a fitness tracker, an AR effect - let me know. PRs are welcome too.

## Links and Resources

- [DetectFaces](https://github.com/taublast/DetectFaces) - sample app with all platforms implemented, source for everything in this article
- [DrawnUi.Maui.Camera](https://github.com/taublast/DrawnUi.Maui.Camera) - `SkiaCamera` control
- [AI Captions and Live Video Processing in .NET MAUI](../VideoRecording/) - previous article in this series
- [MediaPipe Tasks Vision - Android](https://ai.google.dev/edge/mediapipe/solutions/vision/face_landmarker/android) - official Android MediaPipe docs
- [MediaPipe Tasks Vision - iOS](https://ai.google.dev/edge/mediapipe/solutions/vision/face_landmarker/ios) - official iOS MediaPipe docs
- [One Euro Filter](https://gery.casiez.net/1euro/) - the adaptive smoothing algorithm used for mask stabilization
- [DrawnUI for .NET MAUI](https://github.com/taublast/DrawnUi) - the rendering engine behind SkiaCamera
- [SkiaSharp](https://github.com/mono/SkiaSharp) - the 2D graphics library this all runs on

---

*The author is available for consulting and works on drawn applications and custom controls for .NET MAUI. If you need help with custom UI experiences, optimizing performance, or building drawn mobile apps, feel free to reach out.*


<style>

.video-container {
  position: relative;
  padding-bottom: 56.25%;
  height: 0;
  overflow: hidden;
  max-width: 100%;
  margin-bottom: 1em;
}

.video-container iframe {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.video-container-github {
    min-height: 200px;
    margin-bottom: 1em;
}

.video-container-github video {
  max-height: 547px;
  width: 100%;
  height: 100%;
  background: #000;
}

</style>
