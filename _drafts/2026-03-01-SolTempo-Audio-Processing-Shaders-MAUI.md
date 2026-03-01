---
layout: post
title: "SolTempo: Realtime Audio Processing and SKSL Shaders in .NET MAUI"
date: 2026-03-01 12:00:00 +0000
categories: [MAUI, DrawnUI, Audio, Shaders]
tags: [dotnetmaui, skiasharp, drawnui, audio, sksl, shaders]    
description: Building a real-time pitch and BPM detection app using DrawnUI, SkiaCamera audio processing, and live SKSL shaders.
image: /assets/img/soltempo.jpg
---

# Building SolTempo: Realtime Audio Processing and Shaders in .NET MAUI

This article is about **realtime audio processing and analysis in .NET MAUI**, while still keeping the UI very much alive with SKSL shaders, transitions and effects.

Enhancements that DrawnUI for .NET MAUI `SkiaCamera` control recently received, like realtime video and audio processing made this possible. We will touch video processing with realtime encoding in the next article, meanwhile let's have some fun with the audio: control can also work as a standalone audio recorder without using video capabilities.

To demonstrate it I created [SolTempo](https://github.com/taublast/SolTempo): an open-source .NET MAUI app for iOS, Mac Catalyst, Android, and Windows that does realtime note pitch detection + BPM detection.

We showcase a clean, cross-platform audio pipeline where we can:

- capture mic buffers without messing with platform-specific audio APIs,
- optionally apply a transform (Gain +5 in this app, but it could be anything: voice changer, EQ, noise gate…),
- analyze the stream (notes / BPM),
- and drive the visuals from that state.

On a quick note, another motivation for building this (took about a week) was to bring out another SKSL shaders use case for .NET MAUI, like creating a liquid glass simulation and more. While some might think that such capabilities are reserved for different frameworks, using SkiaSharp makes .NET MAUI to play absolutely in the same league.

<img src="../assets/img/sol_screenshots.png" alt="SolTempo" width="800"
style="margin-top: 16px;" />

## SolTempo Features (Quick Overview)

Here is what the app does:

- Real-time note pitch detection for voice and instruments
- Tuning indicator: shows how sharp/flat you are relative to the nearest semitone
- Multiple note notations: Letters, Solfeggio (fixed/movable), Cyrillic, Numbers
- Optional semitones (C#, Eb, etc.) or “natural notes only” mode
- BPM / tempo detection (roughly 40–260 BPM)
- Audio settings: choose input device (or System Default) and enable Gain (+5) for low signals
- Streak achievements (octave / two octaves) with confetti and a fullscreen shader celebration

## The Single Canvas Approach

Like many my previous MAUI apps, SolTempo is completely drawn on a single hardware-accelerated Skia `Canvas`. The only native control we use is the one presented via `DisplayActionSheet`, love using this one to keep platform-native feel for users. 

All the navigation, modals, and popups happen inside this canvas. To make the UI feel attractive SolTempo uses:

- shader-based transitions when switching modules
- shaders for entrance/exit of popups instead of usual scale/fade transforms
- a dynamic liquid glass-like shader backdrop behind the main panel
- a dynamic liquid glass-like shader backdrop behind the bottom icons menu panel
- a constantly drawn audio equalizer at the bottom
- a simple confetti helper when you hit a single octave streak
- a neat animated shader for a double-octave streak achievement

The UI itself is assembled in code (.NET HotReload-friendly), no XAML.

For example the glass panel behind the notes module looks like this:

```csharp
new SkiaBackdrop()
{
	HorizontalOptions = LayoutOptions.Fill,
	VerticalOptions = LayoutOptions.Fill,
	Blur = 0,
	VisualEffects = new List<SkiaEffect>
	{
		new GlassBackdropEffect()
		{
			EdgeOpacity = 0.55f,
			EdgeGlow = 0.95f,
			Emboss = 9.2f,
			BlurStrength = 1.0f,
			Opacity = 0.9f,
			Tint = Colors.Black.WithAlpha(0.33f),
			CornerRadius = 24,
			Depth = 1.66f
		}
	}
}
```

## Realtime Audio with SkiaCamera

If you’ve seen our previous camera/shader experiments (like [Filters Camera](../FiltersCamera/)), you might already know `SkiaCamera` as “the camera control”. But SolTempo uses it in a slightly different way: **audio-only monitoring**.

`SkiaCamera` can provide us with incoming audio buffers directly, so we can build a deterministic, cross-platform audio pipeline on top of it. App continuously captures the audio feed, applies transforms if needed (like an optional +5 audio gain boost for low signals), and analyzes the samples to detect pitch or compute the BPM. Everything is processed on-device and then fed straight into UI visualizers.

### Audio-only mode

SolTempo defines a tiny `SkiaCamera` subclass that disables video and enables audio monitoring:

```csharp
public partial class AudioRecorder : SkiaCamera
{
	public AudioRecorder()
	{
		NeedPermissionsSet = NeedPermissions.Microphone;

		// turn on AUDIO recorder mode
		EnableAudioMonitoring = true;
		EnableAudioRecording = true;

		// turn off VIDEO
		EnableVideoPreview = false;
		EnableVideoRecording = false;
	}

	public float GainFactor { get; set; } = 5.0f;
	public bool UseGain { get; set; }

    // this is where you can hook whatever processing you want
	protected override AudioSample OnAudioSampleAvailable(AudioSample sample)
	{
		if (UseGain && sample.Data != null && sample.Data.Length > 1)
		{
			// Amplify PCM16 audio data in-place, no allocations
			AmplifyPcm16(sample.Data, GainFactor);
		}

		OnAudioSample?.Invoke(sample);
		return base.OnAudioSampleAvailable(sample);
	}
}
```

In this app we do not implement audio recording, but if we did, audio would be then encoded amplified with our gain.  
We just stick to monitoring here:

```csharp
// A sample that passed through OnAudioSampleAvailable processing comes ready for being consumed
private void OnAudioSample(AudioSample sample)
{
    //our BPM module
	if (_musicNotesWrapper.IsVisible)
		NotesModule.AddSample(sample);

    // notes detector module
	if (_musicBPMDetectorWrapper.IsVisible)
		_musicBPMDetector?.AddSample(sample);

    //EQ drawn on bottom
	if (_equalizer.IsVisible)
		_equalizer.AddSample(sample);
}
```

Analising audio could reveil itsself to be a deeper subject, I would like now to focus your attention on the rendering of analisys results.

## Rendering Modules

After we analyse the data received via `AddSample` we need to paint our UI to show results to the user. All modules can do the drawing in two main ways:

* using DrawnUI controls
* painting directly on the SkiaSharp SKCanvas

<TODO>
  
explain how
touch the fact that we have special skiasharp handlers different from standart skiasharp an we all due respect they act differently, they are designed for UI/games rendering with controlled FPS and display sync synchronization.

  </TODO>

## Shaders Everywhere

One of the most interesting parts of SolTempo is the heavy use of SKSL shaders. Instead of basic static backgrounds or standard MAUI animations, we rely on the GPU.

<TODO>
  
touch the fact that we have special skiasharp handlers different from standart skiasharp an we all due respect they act differently, they are designed for UI/games rendering with controlled FPS and display sync synchronization.

  </TODO>

### Liquid Glass Backdrop
Behind the main interface, there is a realtime SKSL shader rendering a liquid glass-like effect. It gives the app a very distinct, modern look that reacts smoothly without taxing the CPU.

This is implemented as a `GlassBackdropEffect` (a small wrapper around `SkiaShaderEffect`) that binds a bunch of uniforms like corner radius, emboss/refraction, edge glow, and tint:

```csharp
public class GlassBackdropEffect : SkiaShaderEffect
{
	public GlassBackdropEffect()
	{
		ShaderSource = @"Shaders\\glass.sksl";
	}

	protected override SKRuntimeEffectUniforms CreateUniforms(SKRect destination)
	{
		var uniforms = base.CreateUniforms(destination);
		var scale = Parent?.RenderingScale ?? 1f;

		uniforms["iCornerRadius"] = CornerRadius * scale;
		uniforms["iEmboss"] = Emboss;
		uniforms["iDepth"] = Depth;
		uniforms["iBlurStrength"] = BlurStrength;
		uniforms["iOpacity"] = Opacity;
		uniforms["iEdgeOpacity"] = EdgeOpacity;
		uniforms["iEdgeGlow"] = EdgeGlow;
		uniforms["iTint"] = new float[] { (float)Tint.Red, (float)Tint.Green, (float)Tint.Blue, (float)Tint.Alpha };

		return uniforms;
	}
}
```

### Animated Popups and Achievements
When you hit a streak of correct notes (full octave, and then a longer “perfect streak”), the app triggers encouraging effects. We used animated shaders to handle the appear and exit transitions of popups, as well as the achievement visual effects. Using shaders for these animations keeps the framerate high even when the audio processing is working hard in the background.

There are two fun bits here:

1. **Shader transition when switching modules**. This is a single-texture transition shader driven by a progress animator. At progress `0.5` the screen is fully hidden, we swap the module, then the reveal phase shows the new state:

```csharp
var fx = new TransitionEffect();
fx.Midpoint += (s, e) =>
{
	ToggleVisualizerMode();
	fx.AquiredBackground = false;
};
fx.Completed += (s, e) =>
{
	_mainStack.VisualEffects.Remove(fx);
	_mainStack.DisposeObject(fx);
};

_mainStack.VisualEffects.Add(fx);
fx.Play();
```

2. **Achievement fullscreen celebration**. When the notes sequence tracker reports “two octaves streak” we add a fullscreen `AchievementEffect` shader (and remove it when done):

```csharp
var fx = new AchievementEffect();
fx.Completed += (s, e) =>
{
	_background.VisualEffects.Remove(fx);
	_background.DisposeObject(fx);
};

_background.VisualEffects.Add(fx);
fx.Play();
```

There is also a simple “confetti helper” for the first achievement, because you can’t ship a music practice app without confetti 😄.

## Built-in Live Shader Editor

Writing SKSL shaders can be a trial-and-error process. To speed this up, I included a built-in shader live editor that runs when the app is compiled for Windows. 

This means you can tweak the SKSL code inside the app, hit save, and instantly see the liquid glass background or the popup transition change in real-time. No need to recompile or restart the app.

In SolTempo this is wired as a debug-only developer feature: on Windows, tapping **Settings** opens a separate window with the editor, preloaded with the current shader code.

The important trick is that we stop loading the shader from file and replace it with in-memory code:

```csharp
public void ChangeShaderCode(string code)
{
	if (_editableShader == null)
		return;

	_editableShader.ShaderSource = null; // do not load from file anymore
	_editableShader.ShaderCode = code;   // set our own code
}
```

It’s a very simple workflow, but for shader tuning it feels like cheating.

## Final Thoughts

SolTempo is not “the ultimate tuner” and not “the ultimate BPM detector”. It’s a compact playground that demonstrates a workflow I really like:

- capture realtime audio,
- optionally process it (Gain, filters, whatever),
- analyze it,
- and render a UI that feels modern (shaders) without breaking the audio loop.

And yes, there is a bit of an agenda here: to show that .NET MAUI is not limited to “forms and lists”. With SkiaSharp and the drawn approach you can ship apps that look and feel very far from the usual.

SolTempo is fully open-source, so if you want to dig in, clone it and start playing:

[SolTempo on GitHub](https://github.com/taublast/SolTempo)

Feel free to grab the code, experiment with the shader editor on Windows, and see what you can build.

Privacy note: SolTempo does not collect, store, or share personal data. Audio analysis happens locally on your device and all data stays on it.

## Links and Resources

* [SolTempo](https://github.com/taublast/SolTempo) - complete source code
* [DrawnUI for .NET MAUI](https://github.com/taublast/DrawnUi) - the canvas rendering engine
* [SkiaSharp](https://github.com/mono/SkiaSharp) - the underlying 2D graphics library
* [SKSL documentation](https://skia.org/docs/user/sksl/) - Skia Shading Language reference

---

 *The author is available for consulting on drawn applications and custom controls for .NET MAUI. If you need help creating custom UI experiences, optimizing performance, or building entirely drawn apps, feel free to reach out.*
