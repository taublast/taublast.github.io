---
layout: post
title: "Advanced Video and Audio Recording With Real-Time Processing for .NET MAUI"
description: "Record video/audio in .NET MAUI and bake overlays, captions, and visualizers directly into the final file - no post-processing step."
date: 2026-02-12 12:00:00 +0000
categories: [MAUI, DrawnUI, Camera, Video]
tags: [dotnetmaui, skiasharp, camera, video, audio, realtime, drawnui]
image: /assets/img/appcam.png
---

# Advanced Video Recording With Real-Time Processing for .NET MAUI

Mobile apps need to be able capture video/audio in a comfortable way, to send live feed data to AI/ML, 
to process video and audio feed before even encoding. Would it be just enhancing audio gain or 
applying a watemark, up to drawing dynamic overlays over video frames being encoded and applying effects, in real-time, no post-processing.

WIth `SkiaCamera` control we already had features:

- capturing video feed in real-time to send small preview frames to AI/ML
- applying effects/overlays to live photo preview in real-time
- appling effects/overlays to hi-res still photo capture while saving, along with injecting metadata

What now have added:

- applying effects/overlays to video being recorded recording/monitored in reatime
- injecting metadata to video being saved
- enhancing/analizing audio being recording/monitored in reatime
- a pre-recording video feature - circular in-memory neverending video recording

New features were developed to be used in a commercial app and have been tested with complex real-time processing while recording Full HD (1980x1080) videos. Supported platforms are Windows, iOS, and Android.

This article will cover the new features, how to use them, and comes with a sample code.

## SkiaCamera Control

If you’ve read my earlier post about [real-time shader filters](../FiltersCamera/), 
you might recall the basics of the [SkiaCamera](https://github.com/taublast/DrawnUi/tree/main/src/Maui/Addons/DrawnUi.Maui.Camera) 
control and the mecanics behind it: reading native camera feed to be processed and rendered with [SkiaSharp](https://github.com/mono/SkiaSharp).
Designed to run inside a DrawnUI canvas, it's easy to be integrated into any existing .NET MAUI app.

I would like to make a quick shout out to [Snapimals app](https://play.google.com/store/apps/details?id=com.snapimals.app), that were among of the first
to adopt it for production.

Today's version can record video in a .NET MAUI app while everything you draw on top of raw frames ends up *inside the final MP4*. 
Dynamic HUDs, speach-to-text captions, audio visualizers..  Use it to take photos, record video or record/monitor just a standalone audio.. 
Inject metadata to video, add GPS location..  
Free and open-source, for **iOS, MacCatalyst, Android and Windows**.

## In Action

### Reacebox app

New features were developed to be used in a commercial app to overlay HUD on a video being recorderd, users can see their speed, lap times and other telemetry data directly on the video they record with the app.

My work on the Racebox app started long ago with Xamarin, this app was heavily using SkiaSharp to replicate a very nice Figma design. 

todo video

After porting it to MAUI there came a time to add a feature to allow users to record video of their races with all the HUDS and results saved in the video.

todo screenshots

 After playing with SkiaCamera for a while, it became clear that there was a place for a challenge to avoid post-processing and draw HUDs directly over video frames in real-time. A lot of time was spent optimizing the code, today it was tested to record Full HD videos at 30 fps with audio and all the SkiaSharp drawings over frames on all supported platforms. 

App it's available on AppStore and GooglePlay, unfortunately the Android version is currently not available in EU and US due to another company owning the trademark there. You can still get it from here: [Racebox](https://github.com/taublast/Racebox)

There are many interesting tricks and optimizations used in the app, I will talk about them in another post if this one receives enough interest. For now lets focus on the SkiaCamera control and it's new features.

todo screenshots:

DrawnUI helped very much, since we can just draw anything on the canvas, we were drawing camera preview with the HUD and overlay with camera and page controls.

The HUD was drawn on live camera frames, frames where shown for preview and sent to video encoder. Controls overlay was just drawn on the screen canvas and was obviously not encoded.

SkiaCamera provides frames as SkCanvas to callbacks, so it's very easy to draw anything on top of the frame. The result was shown in camera preview, with this WYSIWYG concept we get no surprises.


### Sample App

A sample camera testing app comes with the repository, a good starting point to see how to use the control. 
It demonstrates many features, including:
- call OpenAI to generate real-time text-to-speech captions
- audio visualizers 

todo teaser screenshot

I will touch on it a bit later in this article, but first lets see how it was used in a commercial app.


## SkiaCamera in one paragraph

SkiaCamera is a camera control drawn with SkiaSharp, designed for DrawnUI for .NET MAUI. You use it inside a classic MAUI app by placing it into a DrawnUI `Canvas` running in hardware-accelerated mode.

The key difference vs a typical "native camera view" is that SkiaCamera can hand you frames as a SkiaSharp canvas in callbacks. That means you can draw on top, or fully replace the frame with a processed one, and then preview and record that output.

It supports:

- photo capture + post-processing,
- video recording with or without audio,
- standalone audio-only recording (think “voice memo” UX),
- real-time access to audio samples (meters, transcription, AI pipelines),
- real-time preview analysis for AI/ML,
- and (the fun part) **real-time overlay/processing that gets saved into the final file**.

Repository / docs: https://github.com/taublast/DrawnUi/tree/main/src/Maui/Addons/DrawnUi.Maui.Camera

## The Pipeline

Thisr eal-time media pipeline lets you ship features that normally require platform-specific video composition or a post-processing export step. This unlocks things like:

- Record MP4 with your HUD and overlays baked in (speed, lap timers, heart rate, watermarks)
- Burn in guides, timecodes, and branded templates for creators
- Show live captions, and optionally burn them into the video
- Draw audio visualizers that end up inside the final file
- Record audio-only (voice memo UX) using the same control
- Tap into audio samples and preview frames for AI (transcription, classification, scene analysis)

If you want the deeper API map and the full breakdown, the README covers it. This post focuses on the fun part: what you can build and how it looks in code.

One more "wait, what?" feature worth calling out is pre-recording (look-back recording) - capture a few seconds before the user presses record.

## The sample app: CameraTests

This is the sample app I mentioned above in the proof of concept section.

Everything in this article is demonstrated in the MAUI sample app living in the main repo:

https://github.com/taublast/DrawnUi/tree/main/src/Maui/Samples/Camera

It’s not a “hello world” page, but rather a nice playground for you to create your next .NET camera app:

- Main camera controls (formats, device switching, capture mode)
- Recording with **real-time processing ON/OFF** toggle
- **Audio visualizers drawn into the recording overlay** (so they end up inside the final encoded file)
- Real-time audio captions via OpenAI Realtime transcription (fed from camera audio samples)
- Pre-recording toggle and duration control (so you can test look-back recording too)

### Draw on Frames

SkiaCamera provides `FrameProcessor` and `PreviewProcessor` callbacks, which present you with a `SKCanvas`. You can draw on this canvas and modify it in other ways, the result will be encoded.

The fastest way would be indeed to use SkiaSharp primitives to anything, maybe you already have some existing code that draws neat stuff on a canvas or you could ask AI to create one for you.

We are doing something different though, we use DrawnUI controls to conviniently create and layout our overlays.

For example we don't have to use a generic `SkCanvas.DrawText` but instead use a powerful `SkiaLabel` control that we can position and style using familiar properties like `Text`, `HorizontalTextAlignment`, `FontFamily` etc..

### DrawnUI Overlays



### Embeed SkiaSharp code inside DrawnUI

We created some audio processing controls to create nifty vizualizations for incoming sound samples. You would see that an audio visualizer uses for rendering a method that is defined like this:

`public void Render(SKCanvas canvas, float width, float height, float scale)`

This is definetely something designed to just draw on a usual SkiaSharp `SKCanvas`, without any intermidiates. But in the end we wanted to include it into our DrawnUI layout system to be able to size, position and arrange at will, with HotReload support, so we created a very light wrapper for it, an `AudioVisualizer : SkiaLayout` where basically one methood matter for understanding how to embed any SkiaSharp code inside DrawnUI:

```csharp
        protected override void Paint(DrawingContext ctx)
        {
            base.Paint(ctx); //draw control background color

            if (Visualizer != null) //this is the reference to our skiacharp control
            {
                Visualizer.Render(ctx.Context.Canvas, ctx.Destination.Width, ctx.Destination.Height, ctx.Scale);
            }
        }
```

That's it! I would also quickly throw another example that was used to imbeed MauiGraphics rendering inside a DrawnUI canvas.

```csharp
    protected override void Paint(DrawingContext ctx)
    {
        base.Paint(ctx);

        if (Drawable != null) // reference to Maui.Graphics.IDrawable
        {
            Canvas.Canvas = ctx.Context.Canvas;
            var viewport = new RectF(0, 0, ctx.Destination.Width, ctx.Destination.Height);
            ctx.Context.Canvas.Save();
            ctx.Context.Canvas.Translate(ctx.Destination.Left, ctx.Destination.Top);
            Drawable.Draw(Canvas, viewport);
            ctx.Context.Canvas.Restore();
        }
    }
```

We can now draw our brand new `AudioVisualizer` control over video frames without any extra effort, using properties like `HorizontalOptions`, `VerticalOptions`, `WidthRequest`, `HeightRequest` etc..

### Visualizers that end up in the final video

In the sample app we subclass `SkiaCamera` into `AppCamera` and route both preview and recording overlays through a single method:

````csharp
// CameraTests: CameraTestPage.Ui.cs
CameraControl.UseRealtimeVideoProcessing = true;
CameraControl.EnableAudioRecording = true;

CameraControl.FrameProcessor = frame =>
{
	// this draws directly onto the encoder canvas
	CameraControl.DrawOverlay(frame);
};

CameraControl.PreviewProcessor = frame =>
{
	// and this draws onto live preview frames
	CameraControl.DrawOverlay(frame);
};
````

And inside that `DrawOverlay` method, we render HUD + the selected audio visualizer:

````csharp
// CameraTests: AppCamera.cs
public void DrawOverlay(DrawableFrame frame)
{
	var canvas = frame.Canvas;
	var scale = frame.Scale;

	if (IsRecording || IsPreRecording)
	{
		var text = IsPreRecording ? "PRE-RECORDED" : "LIVE";
		canvas.DrawText(text, 50 * scale, 100 * scale, paint);
		canvas.DrawText($"{frame.Time:mm\\:ss}", 50 * scale, 160 * scale, paint);
	}

	if (UseRealtimeVideoProcessing && EnableAudioRecording)
	{
		// this is the part that gets baked into the final file
		_audioVisualizer?.Render(canvas, frame.Width, frame.Height, scale);
	}
}
````

That’s the “aha” moment: **if it’s drawn in `FrameProcessor`, it’s in the file**. No post-processing step.

### Real-time captions via OpenAI (audio comes from the camera)

The same sample app also shows how to grab raw PCM from the camera and feed it into a transcription service.

SkiaCamera exposes live samples via `AudioSampleAvailable`:

````csharp
// CameraTests: CameraTestPage.cs
CameraControl.AudioSampleAvailable += OnAudioCaptured;

private void OnAudioCaptured(byte[] data, int rate, int bits, int channels)
{
	if (_realtimeTranscriptionService != null && _speechEnabled)
	{
		_realtimeTranscriptionService.SetAudioFormat(rate, bits, channels);
		_realtimeTranscriptionService.FeedAudio(data);
	}
}
````

In this repository, the OpenAI implementation uses WebSockets against the Realtime transcription endpoint and a small audio preprocessor (resample + silence gating) before sending.

Captions are shown live using a `RealtimeCaptionsEngine` that maintains a rolling window (partials + committed lines) and renders to a drawn label.

If you want captions to be *burned into the final video file*, the trick is the same as with visualizers: draw the caption text inside `FrameProcessor`.

## Installation and setup (quick)

Install the package:

```bash
dotnet add package DrawnUi.Maui.Camera
```

Initialize DrawnUI in `MauiProgram.cs`:

````csharp
builder.UseDrawnUi();
````

Permissions are platform-specific (camera + mic; and optionally location if you want GPS tagging). The README has the exact XML snippets for iOS/MacCatalyst and Android.

## Minimal XAML: a SkiaCamera inside an accelerated Canvas

The Canvas **must** be accelerated:

````xml
xmlns:draw="http://schemas.appomobi.com/drawnUi/2023/draw"
xmlns:camera="clr-namespace:DrawnUi.Camera;assembly=DrawnUi.Maui.Camera"

<draw:Canvas
	RenderingMode="Accelerated"
	HorizontalOptions="Fill"
	VerticalOptions="Fill"
	Gestures="Lock">

	<camera:SkiaCamera
		x:Name="Camera"
		HorizontalOptions="Fill"
		VerticalOptions="Fill"
		BackgroundColor="Black"
		Facing="Default"
		CaptureMode="Video"
		VideoQuality="Standard"
		EnableAudioRecording="True" />

</draw:Canvas>
````

## Recording basics: start, stop, handle the result

Recording is event-driven:

- `VideoRecordingSuccess` gives you a `CapturedVideo` (file path, duration, etc.)
- `VideoRecordingFailed` gives you an exception
- `VideoRecordingProgress` reports time (not on the UI thread)

Here’s a “minimum viable” flow:

Note: in real apps I recommend calling start/stop from the UI thread (especially the first time, when the OS may show permission prompts).

````csharp
protected override void OnAppearing()
{
	base.OnAppearing();

	Camera.VideoRecordingSuccess += async (_, video) =>
	{
		// Optionally inject GPS + MP4 metadata and save to gallery
		var galleryPath = await Camera.SaveVideoToGalleryAsync(video);
		System.Diagnostics.Debug.WriteLine($"Saved: {galleryPath}");
	};

	Camera.VideoRecordingFailed += (_, ex) =>
	{
		System.Diagnostics.Debug.WriteLine($"Recording failed: {ex}");
	};
}

async Task StartAsync()
{
	// Recommended: let the control handle permissions and lifecycle
	Camera.IsOn = true;

	// If you want a quick “permission gate” hook:
	Camera.CheckPermissions(
		granted: _ => { },
		notGranted: _ => { });

	await Camera.StartVideoRecording();
}

async Task StopAsync()
{
	await Camera.StopVideoRecording();
}
````

## The fun part: bake overlays into the recorded video

This is where the new pipeline shines.

When you set `UseRealtimeVideoProcessing = true`, SkiaCamera switches from the platform’s “native record button” flow to a capture pipeline where **each frame is composed and encoded**, and you get a callback to draw on it.

### 1) Enable real-time capture-video flow

````csharp
Camera.CaptureMode = CaptureModeType.Video;
Camera.UseRealtimeVideoProcessing = true;

// Optional: show exactly what’s being encoded on the preview
Camera.UseRecordingFramesForPreview = true;
````

### 2) Draw your overlay in `FrameProcessor`

`FrameProcessor` is called for each frame that is going into the encoder.

You get a `DrawableFrame`:

- `Canvas` - draw with Skia
- `Width`/`Height`
- `Time` - the timestamp since recording started (perfect for timecodes)
- `Scale` - always `1.0` for recording frames

Example: draw a timecode and a “REC” indicator:

````csharp
Camera.FrameProcessor = frame =>
{
	using var paint = new SKPaint
	{
		Color = SKColors.White,
		IsAntialias = true,
		TextSize = 48
	};

	var timecode = $"{frame.Time:mm\\:ss\\.ff}";
	frame.Canvas.DrawText(timecode, 24, 72, paint);

	paint.Color = SKColors.Red;
	frame.Canvas.DrawCircle(frame.Width - 40, 50, 14, paint);
};
````

### 3) (Optional) draw a matching overlay on preview via `PreviewProcessor`

Preview frames can be a different resolution than the recording stream. SkiaCamera calculates `PreviewScale` for you, so you can keep overlay sizing consistent.

````csharp
Camera.PreviewProcessor = frame =>
{
	using var paint = new SKPaint
	{
		Color = SKColors.Lime,
		IsAntialias = true,
		StrokeWidth = 4 * frame.Scale,
		Style = SKPaintStyle.Stroke
	};

	// simple safe-area rectangle
	var margin = 40 * frame.Scale;
	frame.Canvas.DrawRect(margin, margin, frame.Width - 2 * margin, frame.Height - 2 * margin, paint);
};
````

Now the preview can show guides/overlays while the recorded file gets its own overlay baked in.

## Audio: monitor live samples, or record audio-only

### Live audio monitoring (meters, analysis, “is the room loud?”)

You can subscribe to `AudioSampleAvailable` while the camera is running:

````csharp
Camera.EnableAudioMonitoring = true;
Camera.AudioSampleAvailable += (data, sampleRate, bitsPerSample, channels) =>
{
	// data is PCM, great for meters / ML pipelines
};
````

### Audio-only recording (voice memo UX)

SkiaCamera also supports a clean audio-only workflow.

The switch is simply:

- `EnableVideoRecording = false`
- `EnableAudioRecording = true`

And you still use the same start/stop API:

````csharp
Camera.EnableVideoPreview = false;   // optional: no camera preview UI
Camera.EnableVideoRecording = false; // audio-only
Camera.EnableAudioRecording = true;

await Camera.StartVideoRecording();
...
await Camera.StopVideoRecording();
````

When audio-only is used, `AudioRecordingSuccess` fires (and for compatibility, `VideoRecordingSuccess` also fires with a `CapturedVideo` pointing to the audio file path).

If you want to preprocess the audio samples before they’re written (gain, gating, downmix, resample), override `OnAudioSampleAvailable(AudioSample sample)` in a subclass - that hook is shared across platforms and is a good place to keep your audio pipeline deterministic.

## Pre-recording (“look-back recording”)

This is one of those features that makes users go “wait… how did it capture that?”

Enable it like this:

````csharp
Camera.EnablePreRecording = true;
Camera.PreRecordDuration = TimeSpan.FromSeconds(6);
````

When enabled, SkiaCamera buffers a rolling window of frames before the user commits to the recording. When they actually press record, the final file includes the previous seconds.

More details: https://github.com/taublast/DrawnUi/tree/main/src/Maui/Addons/DrawnUi.Maui.Camera/PreRecording.md

## GPS + metadata injection (yes, for video too)

If you want your recorded videos to contain GPS metadata and camera/app info:

````csharp
Camera.InjectGpsLocation = true;
await Camera.RefreshGpsLocation();

Camera.VideoRecordingSuccess += async (_, video) =>
{
	// You can also set custom metadata here:
	video.Meta ??= new Metadata();
	video.Meta.Author = "Nick Kovalsky";
	video.Meta.Software = "SkiaCamera";

	await Camera.SaveVideoToGalleryAsync(video);
};
````

SkiaCamera will auto-fill missing fields (device model, recording time, etc.) and inject MP4 metadata atoms when saving.

## Performance notes (real talk)

Real-time video processing is powerful, but it’s also real work:

- Keep your `FrameProcessor` cheap: avoid allocations and heavy CPU loops.
- Prefer drawing simple overlays (text, shapes, cached bitmaps).
- If you don’t need overlays baked into the file, keep `UseRealtimeVideoProcessing = false` and use native recording.
- On lower-end devices, treat this like any other rendering pipeline: measure, tune, and build with Release optimizations.

## Links & resources

- SkiaCamera / DrawnUi.Maui.Camera: https://github.com/taublast/DrawnUi/tree/main/src/Maui/Addons/DrawnUi.Maui.Camera
- NuGet: `DrawnUi.Maui.Camera`
- Pre-recording doc: https://github.com/taublast/DrawnUi/tree/main/src/Maui/Addons/DrawnUi.Maui.Camera/PreRecording.md
- Previous post (filters + shaders): [Real-Time Camera Filters with Hardware-Accelerated Shaders in .NET MAUI](../FiltersCamera/)
- DrawnUI for .NET MAUI: https://github.com/taublast/DrawnUi

---

If you end up building something weird and ambitious with this (teleprompter recorder? AI caption burner? sports HUD camera?), I’d love to see it - send me a link, an issue, or a PR.
