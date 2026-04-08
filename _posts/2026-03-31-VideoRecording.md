---
layout: post
title: "AI Captions and Live Video Processing in .NET MAUI"
description: "Build a .NET MAUI video processing pipeline with AI captions, live overlays, audio processing, and look-back capture during recording."
date: 2026-03-31 12:00:00 +0000
categories: [MAUI, DrawnUI, Camera, Video]
tags: [dotnetmaui, skiasharp, camera, video, audio, realtime, drawnui]
image: /assets/img/camhi.jpg
---

## DrawnUi.Maui.Camera

If you just need camera capture in .NET MAUI, there are solid options already: [CommunityToolkit.Maui.Camera](https://learn.microsoft.com/en-us/dotnet/communitytoolkit/maui/views/camera-view), [MediaPicker](https://learn.microsoft.com/en-us/dotnet/maui/platform-integration/device-media/picker), and platform-native APIs.

For the other kind of job: when preview and recording are part of a realtime pipeline, and you want to process frames before they hit the encoder, please meet [DrawnUi.Maui.Camera](https://github.com/taublast/DrawnUi.Maui.Camera).

Best for:

- Live preview processing effects, sending to AI/ML
- Captured hi-res photo post-processing
- Processing video in real-time before encoding
- Audio live processing

<img src="../assets/img/raceland.jpg" alt="Racebox Video Recording" width="800"
style="margin-top: 16px;" />

*Use case: a published .NET MAUI Android app recording video with encoded overlay in real-time.*

Package provides a **SkiaCamera** control with hardware-level options such as stabilization, audio modes (raw, voice, and more), and flexible processing hooks. It is MIT-licensed and supports **iOS, MacCatalyst, Android, and Windows**.

>It is powered by **SkiaSharp** and built for realtime feed processing and post-processing. The project started with native filters on Android (**RenderScript**) and iOS (**Metal**), then moved to SKSL once SkiaSharp hardware acceleration on Windows became practical. That shift made one cross-platform processing path realistic for video and audio workflows.

## What this article covers

We will focus on the control installation and the sample app which comes along with the git repo, with demonstrated features:

- Overlays and shader effects rendered into the encoded file and over preview
- OpenAI-powered real-time captions burned into output
- Live video processing, SKSL shaders
- Pre-recording (look-back capture)

For a quick visual pass you can run the sample app on mobile or even your Windows or Mac machine if you have a camera attached!

Don't miss the [previous article](../SolTempo) that covers audio processing.

## Control Setup

Full control docs entry point is the project [README](https://github.com/taublast/DrawnUi.Maui.Camera).

To use `SkiaCamera` in a **.NET MAUI** app, install the package, initialize DrawnUI, then host the camera inside a hardware-accelerated Skia canvas.

### Install:

```bash
dotnet add package DrawnUi.Maui.Camera
```

### Initialize 

Inside `MauiProgram.cs`:

```csharp
builder.UseDrawnUi();
```

### Consume 

Place inside your page, for example:

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
* For reliable saved feed orientation, lock the app or the camera page to portrait. The UI can still react to landscape rotation, and we will do that below.


### Permissions

Set platform native permissions as documented in the [README](https://github.com/taublast/DrawnUi.Maui.Camera). Then optionally define flags so the control can request them automatically:

```csharp
Camera.NeedPermissionsSet = NeedPermissions.Camera
    | NeedPermissions.Gallery
    | NeedPermissions.Microphone;
```

### Power On/Off

Camera power is controlled by the bindable `IsOn` property. Turn it on when needed, for example after the first canvas draw:

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

If you have a dedicated camera page, you can also flip `IsOn` from your page lifecycle hook. The exact hook depends on your navigation setup.

When the app goes to background, camera state is suspended and restored on resume without extra wiring in most cases.

## Sample App

The repo sample exposes almost every relevant camera setting. Plus we have live audio visualizers, OpenAI captions encoded into final video and SKSL filters. UI is built in C# code. A XAML usage example lives in a separate repo: [DrawnUI for .NET MAUI Demo](https://github.com/taublast/DrawnUi.Maui.Demo).

App UI presents three main parts: 

* Top header for fast switching between Photo and Video modes, plus captions controls.
* Middle quick-control overlay with recording actions and a tappable capture thumbnail.
* Bottom drawer provides large camera settings organized into three sections: `Input`, `Processing`, and `Output`.

`Input` controls camera selection, capture format, and mode.
`Processing` controls realtime work: monitoring, visualizers, gain, and speech recognition.
`Output` controls what gets written: audio/video toggles, codec, pre-record settings, and geotagging.

That split makes the full pipeline visible in one place: input, processing, and encoded output.

For this article, the flow is simple: keep realtime processing on, feed live audio into overlay and speech paths, then record the composed result directly into the saved video.

In the sample app, `SkiaCamera` is subclassed into `AppCamera` and configured for processed recording by default:

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

`UseRealtimeVideoProcessing = true` is the key switch.
Without it, recording is native and overlay is preview-only.
With it, every frame goes through Skia before encoding, so anything drawn in `ProcessFrame` becomes part of the file.

Both handlers receive `DrawableFrame`: it carries the destination `SKCanvas`, source camera `SKImage`, current `Scale`, and `IsPreview` flag. That flag lets us render preview and recording differently when needed. In the sample we keep one shared overlay tree, keep EQ visible in both paths, and only move captions between preview and recording modes.

### UI Orientation

Camera apps usually lock capture UI to portrait, then rotate icons and controls as the device rotates. `SkiaCamera` follows that pattern. You lock page/app orientation, while DrawnUI still gives orientation values so your UI can respond at runtime. In this sample we are rotating icons upon device rotation.

There are native ways to lock a specific page orientation, here we locked the whole app:

**Android:**

Inside `MainActivity.cs`, set `ScreenOrientation` on the activity attribute:

```csharp
[Activity(Theme = "@style/Maui.SplashTheme",
    ScreenOrientation = ScreenOrientation.SensorPortrait,
	...
```

**iOS:**

Edit `Info.plist`:

App Store rules for iPad may require landscape unless `UIRequiresFullScreen` is enabled:

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

Saved photo/video orientation is handled through normal media metadata flows. Depending on platform and player, orientation can be represented either as rotated pixels or metadata tags interpreted by the viewer.

For UI, we mimic standard camera behavior and rotate quick-action icons with device orientation.

This is easily done by subscribing to a DrawnUI event:

```csharp
Super.RotationChanged += OnRotationChanged;
```

And then applying inverse rotation to icons.

## SKSL Video Filters 

We apply video filters, implemented with SKSL shaders to preview, captured photo and captured video.

Because every frame passes through Skia before encoding, SKSL effects can be applied to recorded video in real-time. The saved MP4 will contain filtered frames, no post-processing needed.

The sample app exposes a `VideoEffect` property on `AppCamera`:

```csharp
CameraControl.VideoEffect = ShaderEffect.Retro;
```

`AppCamera` overrides both `RenderPreviewForProcessing` and `RenderFrameForRecording` to apply the selected shader effect before handing frames to preview or encoder. Same effect, same path, different target.

Switch to `ShaderEffect.None` and you are back to clean capture. Switch mid-session and the filter change shows up in the file from that point forward.

Captured still photo is processed before saving to gallery on GPU thread:

```csharp
private async void OnCaptureSuccess(object sender, CapturedImage captured)
{
	if (CameraControl.UseRealtimeVideoProcessing && CameraControl.VideoEffect != ShaderEffect.None)
	{
		var imageWithEffect = await CameraControl.RenderCapturedPhotoAsync(captured, null, image =>
		{
			if (CameraControl.VideoEffect != ShaderEffect.None)
			{
				var shaderEffect = new SkiaShaderEffect()
				{
					ShaderSource = ShaderEffectHelper.GetFilename(CameraControl.VideoEffect),
				};
				image.VisualEffects.Add(shaderEffect);
			}
		}, true);

		captured.Image.Dispose();
		captured.Image = imageWithEffect;
	}

	SaveFinalPhotoInBackground(captured);
}
```

This is from `MainPage.OnCaptureSuccess` in the sample app.

The sample ships with several SKSL presets to play with, and adding your own is a matter of writing a standard SKSL fragment shader.

Shader assets live in the sample under `src/Sample/Resources/Raw/Shaders`.

## Drawn Overlay

SkiaCamera virtual methods `RenderPreviewForProcessing` or `RenderFrameForRecording` are used to prepare the SkCanvas that would then be passed to callbacks `ProcessPreview` or `ProcessFrame` so we could optionally draw over the frames. 

Inside callbacks we can of course use SkiaSharp primitives like `SKCanvas.DrawText`, `DrawRect`, and others.

When drawing some complex controls we can compose overlays with DrawnUI layouts.

Our overlay contains two visible modules:

- an audio visualizer panel in the top-right corner
- a captions panel rendered with `SkiaRichLabel`

```csharp
new SkiaShape()
{
	Type = ShapeType.Rectangle,
	UseCache = SkiaCacheType.ImageDoubleBuffered,
	Margin = 16,
	Padding = new Thickness(12, 10, 12, 12),
	WidthRequest = 220,
	HeightRequest = 138,
	CornerRadius = 22,
	VerticalOptions = LayoutOptions.Start,
	HorizontalOptions = LayoutOptions.End,
	Children =
	{
		new AudioVisualizer()
		{
			Margin = new Thickness(0, 42, 0, 0),
			HorizontalOptions = LayoutOptions.Fill,
			VerticalOptions = LayoutOptions.Fill,
		}
	}
}
```

Notice we used ImageDoubleBuffered cache type for equalizer so that it doesn't slow our frame rendering, Cache would then calculate/draw in background while we fast-draw the last raster. 

The EQ panel can stay where it is for both preview and recording. Captions are different. During preview the app HUD is large and sits over the lower part of the camera feed, so bottom-aligned captions would fight with the controls. For that reason the sample centers the captions panel vertically while drawing preview frames, then moves it back toward the bottom for recorded frames.

Code locations in sample app:

- Overlay composition and captions visual effects: `src/Sample/UI/FrameOverlay.cs`
- Overlay rendering and scaling against frame data: `src/Sample/UI/AppCamera.cs` (`DrawOverlay` and `OnFrameProcessing`)
- Captions feed and transcription wiring: `src/Sample/UI/MainPage.cs`

In `AppCamera.DrawOverlay`, we adapt both by mode and scale.
`layout.AdaptLayoutToMode(frame.IsPreview)` switches preview vs recording caption placement, and `overlayScale` is computed from `frame.Scale` plus camera format so the same layout stays visually stable across preview and encoded frames.

## Use Audio for AI Captions

In the next article we will  feed video data to ML to detect faces in realtime, for now let's use some AI for audio. Real-time speech transcription is wired like this:

```csharp
CameraControl.AudioSampleAvailable += (data, rate, bits, channels)
    => OnAudioCaptured(data, rate, bits, channels);
```

We feed incoming PCM into the OpenAi service:

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

To run the sample, provide your own `Secrets.cs` API key file using the included template.

We can draw received text onto our overlay:

```csharp
_captionsEngine.CaptionsChanged += spans =>
	MainThread.BeginInvokeOnMainThread(()
        => _previewFrameOverlay.SetCaptions(spans));
```

We marshal this callback to the UI thread because caption updates mutate DrawnUI controls (`SkiaRichLabel` text and visibility). Those updates must be serialized on the main thread to avoid cross-thread UI access issues.

Captions are drawn as follow:

```csharp
new SkiaShape()
{
	UseCache = SkiaCacheType.Image,
	Type = ShapeType.Rectangle,
	CornerRadius = 26,
	Margin = new Thickness(20, 0, 20, 40),
	Padding = new Thickness(20, 16, 20, 18),
	HorizontalOptions = LayoutOptions.Center,
	VerticalOptions = LayoutOptions.End,
	Children =
	{
		new SkiaRichLabel()
		{
			FontFamily = "FontText",
			FontSize = 20,
			LineHeight = 1.1,
			TextColor = Colors.White,
			UseCache = SkiaCacheType.Operations,
		}
	}
}
```

When captions are about to disapper we apply a shader for them to dissolve:

```csharp
void AnimateOut(SkiaControl control)
{
	var animExit = new AnimatedShaderEffect()
	{
		UseBackground = PostRendererEffectUseBackgroud.Once,
		ShaderSource = MauiProgram.ShaderRemoveCaption,
		DurationMs = 400
	};

	control.VisualEffects.Add(animExit);
	animExit.Play();
}
```

Since the same overlay handles both preview and recording, captions stay visible live and are burned into the final video with no second export pass. The only layout difference is where they sit: centered during preview so the app HUD does not cover them, then bottom-aligned in the recorded output.


## Video Recording

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

There is also an abort flow, useful mainly for pre-recording scenarios:

```csharp
await CameraControl.StopVideoRecording(true);
```

which discards the recording instead of finalizing it.

## Pre-Recording: Capture Before Live

A rather interesting feature was developed for the Racebox app. Car dynamics measurement starts automatically and it triggers live video recording. At the same time we need those few seconds before that event to be present in the final video.

Another simple use-case i can think of is any sport or family event when you are trying to catch a moment that would happen at an unknown time: pre-recording would record video into memory into a curcular buffer for an unlimited time, when the moment happens - start live recording and seconds before that will be pre-muxxed in the final video!

In sample UI this is exposed as an action sheet with:

```csharp
var durations = new (string Label, int Seconds)[]
{
	("Off", 0),
	("3 seconds", 3),
	("5 seconds", 5),
	("10 seconds", 10),
};

CameraControl.EnablePreRecording = selected.Seconds > 0;
if (selected.Seconds > 0)
	CameraControl.PreRecordDuration = TimeSpan.FromSeconds(selected.Seconds);
```

Enable it in code like this:

```csharp
CameraControl.EnablePreRecording = true;
CameraControl.PreRecordDuration = TimeSpan.FromSeconds(5);
```

Both `IsPreRecording` and `IsRecording` are bindable, so you can drive button morphs, labels, or other UI state directly from them.

For the full breakdown see the dedicated [PreRecording.md](https://github.com/taublast/DrawnUi.Maui.Camera/PreRecording.md) document.

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

This injects location metadata into captured photos and MP4 videos. Whether and how it is shown depends on gallery/player support on the target platform.

With `InjectGpsLocation` enabled your metadata will already contain GPS location when arrived to callback:

```csharp
// attached as CameraControl.RecordingSuccess += OnRecordingSuccess;
private async void OnRecordingSuccess(object sender, CapturedVideo capturedVideo)
{
	//SAVING VIDEO

	captured.Meta.Vendor = "Me";
	captured.Meta.Model = "My Recorder";
	captured.Meta.Software = "My App";

	var publicPath = await CameraControl.MoveVideoToGalleryAsync(capturedVideo);
}
```

For still photos, metadata is richer: the library `Metadata` model includes EXIF-style fields (ISO, shutter, aperture, lens info, orientation, GPS, timestamp, software/vendor/model), and those values are written when saving JPG streams to gallery:

```csharp
// attached as CameraControl.CaptureSuccess += OnCaptureSuccess;
private async void OnCaptureSuccess(object sender, CapturedImage captured)
{
	//SAVING PHOTO

	captured.Meta.Software = "My App";
	//feel free to explore and change captured.Meta

	var path = await CameraControl.SaveToGalleryAsync(captured, "MyAppAlbum");
}
```

## Final thoughts

If your app needs branded recording, AI-assisted media, sports telemetry, guided capture, captions, or audio-reactive overlays, this control is designed for that class of workflow.

If you build something cool with it, let me know. I’d be happy to see it help other builders too. PRs are welcome!

## Links and resources

- [SkiaCamera / DrawnUi.Maui.Camera](https://github.com/taublast/DrawnUi.Maui.Camera) - control repository and documentation
- [Sample App](https://github.com/taublast/DrawnUi.Maui.Camera/tree/main/src/Sample) - used in this article
- [Racebox](https://github.com/taublast/Racebox) - commercial app that pushed the recorded-overlay workflow
- [Real-Time Camera Filters with Hardware-Accelerated Shaders in .NET MAUI](../FiltersCamera/) - earlier
- [Building a Real-time Audio Processing App with SKSL Shaders in .NET MAUI](../SolTempo/) - earlier post
- [DrawnUI for .NET MAUI](https://github.com/taublast/DrawnUi) - UI rendering engine behind this control
- [SkiaSharp](https://github.com/mono/SkiaSharp) - the underlying 2D graphics library

---

 *The author is available for consulting and works on drawn applications and custom controls for .NET MAUI. If you need help creating custom UI experiences, optimizing performance, or building entirely drawn apps, feel free to reach out.*

