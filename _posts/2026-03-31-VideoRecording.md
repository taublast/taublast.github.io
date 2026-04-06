---
layout: post
title: "AI Captions and Live Video Processing in .NET MAUI"
description: "Build a .NET MAUI video processing pipeline with AI captions, live overlays, audio processing, and look-back capture during recording."
date: 2026-03-31 12:00:00 +0000
categories: [MAUI, DrawnUI, Camera, Video]
tags: [dotnetmaui, skiasharp, camera, video, audio, realtime, drawnui]
image: /assets/img/camhi.jpg
---

# AI Captions and Live Video Processing in .NET MAUI

## DrawnUi.Maui.Camera

Several solid ways are available today for recording videos in .NET MAUI. [CommunityToolkit.Maui.Camera](https://learn.microsoft.com/en-us/dotnet/communitytoolkit/maui/views/camera-view), MAUI [MediaPicker](https://learn.microsoft.com/en-us/dotnet/maui/platform-integration/device-media/picker) and more.
For non-standard cases, like applying video filters, HUDs and watermarks, processing audio or feeding frames to AI/ML in real-time, we can consider the [DrawnUi.Maui.Camera](https://github.com/taublast/DrawnUi.Maui.Camera) package.  
Best for:  

- Live preview processing effects, sending to AI/ML
- Captured hi-res photo post-processing
- Processing video in real-time before encoding
- Audio live processing

<img src="../assets/img/raceland.jpg" alt="Racebox Video Recording" width="800"
style="margin-top: 16px;" />

*Use case: a published .NET MAUI Android app recording video with encoded overlay in real-time.*

Package provides a **SkiaCamera** control with useful hardware-level options like video stabilization, audio mode (raw, voice etc) and more. It is open source MIT software and supports **iOS, MacCatalyst, Android, and Windows**.

>Powered by **SkiaSharp** and designed for feed realtime/post processing. Born from a case of real-time filters applied to native camera preview and photos with **RenderScript** on Android and **Metal** shaders on iOS. After SkiaSharp introduced hardware acceleration for Windows it became worth to port all to SkiaSharp SKSL shaders. Then SkiaSharp demonstrated much freedom to process and draw camera feed, so video and audio processing were added.

## Docs

There is actually a [README](https://github.com/taublast/DrawnUi.Maui.Camera) serving as root to underlying docs in the repo. The [previous article](https://taublast.github.io/posts/SolTempo/) about SkiaCamera audio processing and  today we will focus on video recording. The provided sample app also handles still photo capture. [The sample app](https://github.com/taublast/DrawnUi.Maui.Camera/tree/main/src/Samples/SkiaCameraDemo) coming with the repo is a powerful playground with almost all the camera settings, live audio visualizers, OpenAi powered captions encoded over the final video, SKSL video filters and much more. We will talk about this sample below.

<!-- TODO: add hero video showing the sample app recording with EQ + live captions overlay -->

<!-- TODO: screeshots or video -->

## Control Setup

To use `SkiaCamera` inside a **.NET MAUI** app we need to install the package, initialize it, then drop the camera control into a hardware-accelerated **SkiaSharp** canvas.

### Install:

```bash
dotnet add package DrawnUi.Maui.Camera
```

### Initialize 

Inside `MauiProgram.cs`:

```csharp
builder.UseDrawnUi();
```

### UI 

Position inside your app page, for example:

```xml
xmlns:draw="http://schemas.appomobi.com/drawnUi/2023/draw"
xmlns:camera="clr-namespace:DrawnUi.Camera;assembly=DrawnUi.Maui.Camera"

<Grid VerticalOptions="Fill" HorizontalOptions="Fill">
	<draw:Canvas
		HorizontalOptions="Fill"
		VerticalOptions="Fill"
		RenderingMode="Accelerated"
		Gestures="Lock">

		<camera:SkiaCamera
			x:Name="Camera"
			HorizontalOptions="Fill"
			VerticalOptions="Fill"
			BackgroundColor="Black"
			CaptureMode="Video" />

	</draw:Canvas>
</Grid>
```

Important:
* Keep the container stable: no `Auto` rows, no unset width or height requests without a `Fill`.
* For correct saved feed orientation lock the app or the camera page to portrait. That does not mean we cannot respond to landscape rotation in the UI, and we will do exactly that in the example below.


### Permissions

Setup permissions per platform as described in the [README](https://github.com/taublast/DrawnUi.Maui.Camera). Then optionally define permission flags for your specific control so it can automatically check and request them:

```csharp
Camera.NeedPermissionsSet = NeedPermissions.Camera
    | NeedPermissions.Gallery
    | NeedPermissions.Microphone;
```

### Power On/Off

The camera power is controlled by a bindable `IsOn` property. Turn it on when we need it, for example right after the canvas appears:

```csharp
// can attach this event handler in XAML too
Canvas.WillFirstTimeDraw += (sender, context) =>
{
	if (CameraControl != null)
	{
		Tasks.StartDelayed(TimeSpan.FromMilliseconds(500), () =>
		{
			CameraControl.IsOn = true;
		});
	}
};
```

In case you have a dedicated camera page an obvious hook would be the one when your camera page did appeared: the exact code would depend on your app navigation implementation.

Camera will automatically turn off without changing `IsOn` when the app goes to background, and will restore its state when app resumes, no additional coding is needed for this. 

## Sample App

Repo sample app will present almost all camera settings, live audio visualizers, OpenAi captions encoded with final video, SKSL video filters and much more. UI will be constructed with code. A XAML usage example lives in a separate [DrawnUI for .NET MAUI Demo](https://github.com/taublast/DrawnUi.Maui.Demo) repo.

App UI presents 3 main parts: 

* Top header allows fast switch between Photo an Video modes, and AI captions control.
* A middle overlay quick camera control buttons also presents a captured feed tappable thumbnail
* Bottom drawer provides large camera settings organized into three sections: `Input`, `Processing`, and `Output`.

`Input` is where the sample switches between photo and video mode, picks the active camera, picks the audio device, and chooses the current capture format. `Processing` is where the fun starts: toggle real-time processing, turn audio monitoring on, switch visualizers, boost gain, and enable speech recognition. `Output` decides what the app actually saves: audio on or off, video on or off, audio codec, pre-recording, pre-record duration, and geotagging.

That layout is useful because it makes the whole recording pipeline visible in one place. We are not just looking at a camera preview. We are looking at input settings, live processing, and final recording output all wired together.

For this article the route is simple: keep real-time processing on, feed live audio into the overlay and speech pipeline, and record the composed result directly into the saved video.

In the sample app, we subclassed `SkiaCamera` into an `AppCamera` for convenience and enabled the processed recording path by default:

```csharp
public partial class AppCamera : SkiaCamera
{
	public AppCamera()
	{
		NeedPermissionsSet = NeedPermissions.Camera | NeedPermissions.Gallery | NeedPermissions.Microphone;
		InjectGpsLocation = true;

		UseRealtimeVideoProcessing = true;
		VideoQuality = VideoQuality.Standard;
		EnableAudioRecording = true;

		ProcessFrame = OnFrameProcessing;
		ProcessPreview = OnFrameProcessing;
	}
}
```

`UseRealtimeVideoProcessing = true` is the key switch. Without it, the camera records natively and the overlay appears on screen only. With it, every frame passes through Skia before the encoder sees it — so anything drawn in `ProcessFrame` is permanently in the file. If your overlay renders during `ProcessFrame`, it is not a screen decoration anymore — it becomes part of the encoded media.

Both handlers receive a `DrawableFrame`: a struct carrying the `SKCanvas` to draw into, the source camera `SKImage`, the current `Scale`, and an `IsPreview` flag. That flag lets you render differently for the live screen versus the saved file. In our sample we keep one shared overlay tree, leave the audio EQ visible in both paths, and only change the captions placement depending on whether the current frame is preview or recording.

### UI Orientation

Camera apps usually lock their UI in portrait orientation, then respond to device rotation by rotating icons and controls. `SkiaCamera` was designed in that spirit and expects you to lock the container page or the whole app in portrait, while DrawnUI still provides device orientation info in degrees and enums so the UI can react at runtime.

There are native ways to lock a specific page orientation, but in this sample we locked the whole app:

**Android:**

Inside `MainActivity.cs`, edit the decoration attribute for a limited `ScreenOrientation`:

```csharp
[Activity(Theme = "@style/Maui.SplashTheme",
    ScreenOrientation = ScreenOrientation.SensorPortrait,
	...
```

**iOS:**

Edit `Info.plist`:

AppStore requires apps to support landscape for iPad unless we set `UIRequiresFullScreen` too:

```xml
<key>UIRequiresFullScreen</key>
<true/>
<key>UISupportedInterfaceOrientations</key>
<array>
	<string>UIInterfaceOrientationPortrait</string>
</array>
<key>UISupportedInterfaceOrientations~ipad</key>
<array>
	<string>UIInterfaceOrientationPortrait</string>
	<string>UIInterfaceOrientationPortraitUpsideDown</string>
</array>
```

Saved photo and video output will respect the device orientation used when capturing and will be presented correctly in galleries and viewers. Sometimes the frames are stored unrotated and the file metadata carries the orientation used by the viewer.

For the app UI we mimicked the standard Android camera behavior and rotate quick-access icons when the device rotates:

<!-- TODO: add video showing icon rotation and portrait-locked camera UI -->

This is easily done by subscribing to a DrawnUI event:

```csharp
Super.RotationChanged += OnRotationChanged;
```

And then applying inverse rotation to icons.

## SKSL Video Filters — in the file, not just the preview

This is the part that still makes me happy every time I think about it.

Because every frame passes through Skia before the encoder sees it, SKSL shader effects are not limited to the preview. They get applied to the recording too. The MP4 you save already has the filter baked in — no post-processing step, no re-encode, nothing extra.

The sample app exposes a `VideoEffect` property on `AppCamera`:

```csharp
CameraControl.VideoEffect = ShaderEffect.Retro;
```

`AppCamera` overrides both `RenderPreviewForProcessing` and `RenderFrameForRecording` to apply the active shader effect before handing the frame off — to the screen in one case, to the encoder in the other. The same SKSL shader that colors the preview is literally burned into every encoded frame as you record.

Switch to `ShaderEffect.None` and you are back to clean capture. Switch mid-session and the filter change shows up in the file from that point forward.

The sample ships with several SKSL presets to play with, and adding your own is a matter of writing a standard SKSL fragment shader.

<!-- TODO: add side-by-side screenshot of same scene with and without a filter applied -->

## Drawn Overlay

You can of course draw directly with `SKCanvas.DrawText`, `DrawRect`, and other SkiaSharp primitives. Sometimes that is the right thing to do.

In the sample app I wanted something richer and easier to iterate on, so the overlay is built as a DrawnUI layout and then rendered onto frames.

We could build separate overlay trees for preview and recording. That is sometimes the right call, especially if the two paths have very different visuals or lifetimes. In this sample we went the other way and reused one overlay instance. That keeps memory use lower, keeps the visualizer and captions state in one place, and still lets us adapt parts of the layout per frame.

Inside the overlay, the interesting bit is the double-buffered wrapper:

```csharp
new SkiaLayer()
{
	VerticalOptions = LayoutOptions.Fill,
	HorizontalOptions = LayoutOptions.Fill,
	UseCache = SkiaCacheType.ImageDoubleBuffered,
	Children =
	{
		// visualizer panel + captions panel
	}
}
```

This matters because the encoder thread wants a fast snapshot of the overlay without stalling on layout work every frame. The overlay still feels like regular DrawnUI composition, but the caching strategy is chosen for a recording pipeline.

That overlay contains two visible modules:

- an audio visualizer panel in the top-right corner
- a captions panel rendered with `SkiaRichLabel`

The EQ panel can stay where it is for both preview and recording. Captions are different. During preview the app HUD is large and sits over the lower part of the camera feed, so bottom-aligned captions would fight with the controls. For that reason the sample centers the captions panel vertically while drawing preview frames, then moves it back toward the bottom for recorded frames.

That switch is tiny but useful, and the overlay updates only when the mode actually changes:

```csharp
public bool AdaptLayoutToMode(bool isPreview)
{
	if (_wasPreviewMode == isPreview)
	{
		return false;
	}

	_wasPreviewMode = isPreview;
	_captionsPanel.VerticalOptions = isPreview ? LayoutOptions.Center : LayoutOptions.End;

	return true;
}
```

And inside `OnFrameProcessing` we call `AdaptLayoutToMode(frame.IsPreview)` before measuring and rendering the overlay.

So we get a proper layout tree that can still be rendered onto live frames.

<!-- TODO: add screenshot of CameraTests overlay with EQ panel + captions panel visible -->

## Feeding the overlay with live audio

The sample app also uses the camera’s live audio path. In `AppCamera`, `OnAudioSampleAvailable` is overridden so audio can be modified and then forwarded to the overlay visualizers:

```csharp
protected override AudioSample OnAudioSampleAvailable(AudioSample sample)
{
	if (UseGain && sample.Data != null && sample.Data.Length > 1)
	{
		AmplifyPcm16(sample.Data, GainFactor);
	}

	OnAudioSample?.Invoke(sample);

	if (VideoDataOverlay is IAppOverlay appOverlay)
	{
		appOverlay.AddAudioSample(sample);
	}

	return base.OnAudioSampleAvailable(sample);
}
```

Two details matter in this flow:

- the PCM gain is applied in place, with no extra allocation
- the same processed audio sample can drive both visual feedback and the encoder path

So the visualizer is not some fake animation layered on top of the UI. It is reacting to the same audio stream that is being monitored and, if enabled, recorded.

The sample can cycle between several visualizers such as peak monitor, VU meter, oscillograph, sound bars, waveform bars, and a radial gauge.

One thing to keep in mind: audio samples only surface when `EnableAudioMonitoring = true`. That flag gates `OnAudioSampleAvailable` — and since the captions pipeline feeds from the same stream, it is a prerequisite for speech transcription too.

## Captions from the camera audio

The same audio stream drives real-time speech transcription. Wire up two event handlers — one feeding the transcription service, one routing caption lines back into the overlay:

```csharp
CameraControl.AudioSampleAvailable += (data, rate, bits, channels)
    => OnAudioCaptured(data, rate, bits, channels);

_captionsEngine.CaptionsChanged += spans =>
    MainThread.BeginInvokeOnMainThread(()
        => _previewFrameOverlay.SetCaptions(spans));
```

Then feed incoming PCM into the service:

```csharp
private void OnAudioCaptured(byte[] data, int rate, int bits, int channels)
{
	if (_realtimeTranscriptionService != null && IsSpeechEnabled)
	{
		if (rate != _lastAudioRate || bits != _lastAudioBits || channels != _lastAudioChannels)
		{
			_lastAudioRate = rate;
			_lastAudioBits = bits;
			_lastAudioChannels = channels;
			_realtimeTranscriptionService.SetAudioFormat(rate, bits, channels);
		}

		_realtimeTranscriptionService.FeedAudio(data);
	}
}
```

The implementation uses a WebSocket to the OpenAI Realtime transcription endpoint and passes audio through `AudioSampleConverter` first, which handles resampling to 24 kHz and silence gating. To run the sample you will need your own `Secrets.cs` with the API key — the repo includes a template. An `AzureSpeechTranscriptionService` is also included as a drop-in alternative if you prefer Azure Cognitive Services.

`RealtimeCaptionsEngine` maintains a rolling window of caption lines:

- partial deltas are appended as they stream in
- committed phrases become finalized lines
- older lines expire and fade out through an `AnimatedShaderEffect` — a shader-driven animation that runs through the same overlay pipeline, so it renders correctly in recorded frames too

Since the same overlay handles both preview and recording, captions stay visible live and are burned into the final video with no second export pass. The only layout difference is where they sit: centered during preview so the app HUD does not cover them, then bottom-aligned in the recorded output.

<!-- TODO: add video showing live speech captions over preview and the saved file -->

## Wrapping existing renderers into DrawnUI

One thing I like in this sample is that the visualizer code itself is not forced to become a “UI control first” design.

The visualizer implementations are just renderers that know how to draw onto SkiaSharp:

```csharp
public void Render(SKCanvas canvas, SKRect destination, float scale)
```

Then `AudioVisualizer : SkiaLayout` wraps that into the DrawnUI layout system:

```csharp
protected override void Paint(DrawingContext ctx)
{
	base.Paint(ctx);

	if (Visualizer != null)
	{
		Visualizer.Render(ctx.Context.Canvas, DrawingRect, ctx.Scale);
	}
}
```

This is a very practical pattern.

You keep a renderer that can still work as plain SkiaSharp drawing code, but you gain layout, alignment, sizing, transforms, caching, and hot reload friendliness by hosting it inside DrawnUI.

That same approach works for other rendering systems too. If you have existing drawing code, you do not need to throw it away to use it inside the camera overlay pipeline.

## Start and stop recording

The actual recording flow stays straightforward:

```csharp
if (CameraControl.IsRecording)
{
	await CameraControl.StopVideoRecording();
}
else
{
	await CameraControl.StartVideoRecording();
}
```

On success, it moves the final result to the gallery:

```csharp
private async void OnVideoRecordingSuccess(object sender, CapturedVideo capturedVideo)
{
	var publicPath = await CameraControl.MoveVideoToGalleryAsync(capturedVideo, MauiProgram.Album);
	_lastSavedVideoPath = publicPath;
}
```

There is also an abort flow:

```csharp
await CameraControl.StopVideoRecording(true);
```

which discards the recording instead of finalizing it.

## Audio-only recording is part of the same control

Video is the headliner in this article, but we can switch the same control into audio-only recording too.

The switch is simple:

- `EnableVideoRecording = false`
- `EnableAudioRecording = true`

So if the app only needs voice notes, spoken annotations, or some other audio-first workflow, you do not have to introduce a second media component just to get there.

And the same `OnAudioSampleAvailable(AudioSample sample)` hook is still the right place if you want deterministic preprocessing such as gain, downmixing, or gating before the encoder sees the samples.

## Pre-recording: capture a few seconds before the event

One of the nicest tricks in the sample app is pre-recording, also known as look-back recording.

Enable it like this:

```csharp
CameraControl.EnablePreRecording = true;
CameraControl.PreRecordDuration = TimeSpan.FromSeconds(5);
```

`StartVideoRecording()` becomes a 3-state toggle in this mode. First call sets `IsPreRecording = true` — the camera starts filling an in-memory circular buffer but writes nothing to disk. Second call sets `IsRecording = true` — the buffered frames are prepended to the file and live recording begins. The saved clip opens from a few seconds before the user pressed record, which is exactly what you want for logic-triggered capture or sports moments that happen faster than human reaction time.

Both `IsPreRecording` and `IsRecording` are bindable, so you can drive button morphs, labels, or other UI state directly from them.

The sample UI exposes quick duration options: Off, 3, 5, and 10 seconds. For the full breakdown see the dedicated [PreRecording.md](https://github.com/taublast/DrawnUi.Maui.Camera/PreRecording.md) document.

## GPS and metadata injection

The sample camera subclass also enables GPS metadata by default:

```csharp
InjectGpsLocation = true;
```

and refreshes location when the camera turns on:

```csharp
if (CameraControl.InjectGpsLocation)
{
	_ = CameraControl.RefreshGpsLocation();
}
```

This way not only `SkiaCamera` will inject location metadata into a captured photo, but into a video MP4 as well, which will show in all apps supporting this, like iOS or Android built-in gallery.

## Final thoughts

If your app needs branded recording, AI-assisted media, sports telemetry, guided capture, captions, or audio-reactive overlays, this control is aimed straight at that kind of problem. 

I hope that `SkiaCamera` will help you create great things. PRs are always welcome!

## Links and resources

- [SkiaCamera / DrawnUi.Maui.Camera](https://github.com/taublast/DrawnUi.Maui.Camera) - control repository and documentation
- [CameraTests sample app](https://github.com/taublast/DrawnUi.Maui.Camera/tree/main/src/Samples/SkiaCameraDemo) - sample app used in this article
- [Pre-recording documentation](https://github.com/taublast/DrawnUi.Maui.Camera/PreRecording.md) - implementation and usage details
- [Racebox](https://github.com/taublast/Racebox) - commercial app that pushed the recorded-overlay workflow
- [Previous article: Real-Time Camera Filters with Hardware-Accelerated Shaders in .NET MAUI](../FiltersCamera/) - earlier post focused on preview/photo processing
- [DrawnUI for .NET MAUI](https://github.com/taublast/DrawnUi) - the UI rendering engine behind this control
- [SkiaSharp](https://github.com/mono/SkiaSharp) - the underlying 2D graphics library

---

If you end up building something weird and ambitious with this, like a sports HUD recorder, a teleprompter capture app, or an AI caption burner, I would love to see it.

