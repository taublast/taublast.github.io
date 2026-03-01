---
layout: post
title: "SolTempo: Realtime Audio Processing and SKSL Shaders in .NET MAUI"
date: 2026-03-01 12:00:00 +0000
categories: [MAUI, DrawnUI, Audio, Shaders]
tags: [dotnetmaui, skiasharp, drawnui, audio, sksl, shaders]    
description: Building a real-time pitch and BPM detection app using DrawnUI, SkiaCamera audio processing, and live SKSL shaders.
image: /assets/img/soltempo_git.jpg
---

# Building SolTempo: Realtime Audio Processing and Shaders in .NET MAUI

This article is about **realtime audio processing and analysis in .NET MAUI**, while making an attractive UI with SKSL shaders, transitions and effects.

Recent enhancements shipped for DrawnUI’s `SkiaCamera` control (realtime video + audio processing) made this possible. I will touch video processing with realtime encoding in the next article, meanwhile let’s have some fun with the audio: our control can also work in audio-only monitoring mode without video capabilities.

[SolTempo](https://github.com/taublast/SolTempo) open-source .NET MAUI app for iOS, Mac Catalyst, Android, and Windows does realtime note pitch+BPM detection and showcases a clean, cross-platform audio pipeline:

- capture mic audio in a simple way
- apply optional transforms (Gain +5 in this app, it could be anything: voice changer, EQ, noise gate…),
- analyze audio samples (notes / BPM)
- render visuals from that state

Another motivation for building this (took about a week) app was to bring out another SKSL shaders use case for .NET MAUI, like creating a liquid glass simulation and some more. This kind of “everything can be drawn with Skia” is often associated with Flutter, but SkiaSharp makes it possible for .NET MAUI to play in the same league.

<img src="../assets/img/sol_screenshots.png" alt="SolTempo" width="800"
style="margin-top: 16px;" />

App is currently available in [AppStore](todo) and [GooglePlay](todo), you might consider installing it before further reading.

## SolTempo Features (Quick Overview)

Here is what the app does:

- Real-time note pitch detection for voice and instruments
- Tuning indicator: shows how sharp/flat you are relative to the nearest semitone
- Multiple note notations: Letters, Solfeggio (fixed/movable), Cyrillic, Numbers
- Optional semitones (C#, Eb, etc.) or “natural notes only” mode
- BPM / tempo detection (roughly 40–260 BPM)
- Audio settings: choose input device (or System Default) and enable Gain (+5) for low signals
- Streak achievements ("Full Octave" / "Perfect Streak") with confetti and a fullscreen shader celebration

## The Single Canvas Approach

Like many of my previous MAUI apps, SolTempo is completely drawn on a single hardware-accelerated SkiaSharp-backed `Canvas`. The other native control we use is the one presented via `DisplayActionSheet` — love using this one to keep platform-native feel for users.

All the navigation, modals, and popups happen inside the canvas. To make the UI feel pleasant SolTempo uses:

- shader-based transitions when switching modules
- shaders for entrance/exit of popups instead of usual scale/fade transforms
- a dynamic liquid glass-like shader backdrop behind the main panel
- a dynamic liquid glass-like shader backdrop behind the bottom icons menu panel
- a constantly drawn audio equalizer at the bottom
- a simple confetti helper when you hit a "Full Octave" streak
- a neat animated shader for the "Perfect Streak" achievement

The UI itself is assembled in code (.NET HotReload-friendly), no XAML this time, and uses DrawnUI for layouts, gestures, shaders etc.

For example creating the liquid glass panel behind the notes module looks like this:

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

The backdrop captures the background, a custom visal effect applies a shader to it. You can easily create your effects from scratch or subclassing some of the existing. The `GlassBackdropEffect` took a `SkiaShaderEffect` and wired up some custom properties on top for use with the `glass.sksl` shader shipped inside the `Resources\Raw` MAUI app folder. We would see it in more details later in this article inside the `Liquid Glass Backdrop` section.

## Realtime Audio with SkiaCamera

If you’ve seen previous camera/shader experiments (like [Filters Camera](../FiltersCamera/)), you might already know `SkiaCamera` control. But SolTempo uses it in a slightly different way: **audio-only monitoring**.

`SkiaCamera` can provide incoming audio buffers directly, so we can build a deterministic, cross-platform audio pipeline on top of it. The app continuously captures the audio feed, applies transforms if needed (like an optional +5 audio gain boost for low signals), and analyzes the samples to detect pitch or compute the BPM. Everything is processed on-device and then fed straight into UI visualizers.

### Audio-only mode

SolTempo defines a tiny `SkiaCamera` subclass that disables video and enables audio monitoring:

```csharp
public partial class AudioRecorder : SkiaCamera
{
	public AudioRecorder()
	{
        // flags for permissions that will be required when turning control On.
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

Notice that in SolTempo we do not record (save audio to disk), we stick to monitoring + analysis. But in case you were recording, processing hook `OnAudioSampleAvailable` would be also used to transform audio before it would go to realtime audio encoder.

Now that the sample is ready to be consumed:

```csharp
//we hooked Recorder.OnAudioSample += OnAudioSample;
// now a sample that passed through processing comes in
private void OnAudioSample(AudioSample sample)
{
	// notes detector module
	if (_musicNotesWrapper.IsVisible)
		NotesModule.AddSample(sample);

	// our BPM module
	if (_musicBPMDetectorWrapper.IsVisible)
		_musicBPMDetector?.AddSample(sample);

	// EQ drawn on bottom
	if (_equalizer.IsVisible)
		_equalizer.AddSample(sample);
}
```

As audio analysis could easily become a deep subject, let's now focus on modules rendering.

## Rendering Modules

After we analyzed the data received via `AddSample` we need to paint our UI to show results to the user. We use DrawnUI for NET MAUI to be able to unleash the power of SkiaSharp for rendering UIs. It brings is i'ts own `Canvas` handlers (adapted for UI rendering, fps-control, display sync) and a comfortable to use WPF/MAUI-like layout system along with gestures support and much more.

So in SolTempo modules can access SkiaSharp canvas to draw anything in to main ways, and mix them freely:

- **DrawnUI controls** (`SkiaLabel`, `SkiaShape`, layouts) for everything that feels like UI
- **Direct SKCanvas painting** for “pure drawing” like waveforms, EQ shapes etc...

### Use Drawn Controls

A DrawnUI control is drawn on every frame when it and all of its parents are not cached or it's cache is invalidated with an `Update()`. Why caching? Intead of drawing/calculating layouts/shadows/fonts etc on every frame we can fast draw either a pre-rendered bitmap (`SkImage`) or a previously recorded set of drawing operations (`SkPicture`). Using caching properly can make DrawnUI to practically operate in **retained mode**.

A cached control will be invalidated when some child property changes, for example a `Text` property of a `SkiaLabel `, or an `Update` was called to ivalidate cache. So we have to invalidate manualy in case we processed audio and we want to draw **changed** visual EQ graphic. Otherwise the control representing an audio module or even its top parent would just be fast drawn from cache or even better: not invalidating the `Canvas` at all if other controls didn't change either. The app canvas redraws only if something really changed, contrary to the usual SkiaSharp usage flow.

Speaking of example, the module detecting BPM is created as follows:

```csharp
public AudioMusicBPM()
{
    UseCache = SkiaCacheType.Operations;

    Children = new List<SkiaControl>
    {
        new SkiaLabel
        {
            FontSize = 140,
            //MonoForDigits = "8", <-- this would make font act as mono, digits will take width of "8" and text will not "jump" when number changes, might useful for HUDs etc. We don't use this on purpose here to get a more vivid and less "toolish" look.
            CharacterSpacing = 5.0,
            IsParentIndependent = true,
            Margin = new (2,16),
            MaxLines = 1,
            LineBreakMode = LineBreakMode.CharacterWrap,
            UseCache = SkiaCacheType.Operations,
            FontAttributes = FontAttributes.Bold,
            FontFamily = AppFonts.Default,
            TextColor = Colors.White,
            HorizontalOptions = LayoutOptions.Center,
        }.Assign(out _labelBpm),

        new SkiaLabel
        {
            Text = "BPM",
            Margin = new(0,150,0,0),
            FontSize = 24,
            FontFamily = AppFonts.Default,
            TextColor = Colors.Gray,
            HorizontalOptions = LayoutOptions.Center,
            UseCache = SkiaCacheType.Operations,
        }.Assign(out _labelBpmUnit),

        new SkiaLabel
        {
            FontSize = 19,
            Margin = new(0,180,0,0),
            FontFamily = AppFonts.Default,
            TextColor = Colors.LimeGreen,
            HorizontalOptions = LayoutOptions.Center,
            UseCache = SkiaCacheType.Operations,
        }.Assign(out _labelConfidence),

        new SkiaLabel
        {
            Margin = new Thickness(16,40),
            Text = "Tap to reset BPM metering",
            FontSize = 22,
            FontFamily = AppFonts.Default,
            TextColor = Colors.LightGray,
            VerticalOptions = LayoutOptions.Start,
            HorizontalOptions = LayoutOptions.Center,
            UseCache = SkiaCacheType.Operations,
            IsVisible = true,
        }.Assign(out _labelNoSignal),

    };
}

```

You could also use XAML too for DrawnUI as demonstrated by other articles/apps, today i am mainly [using code-behind](https://drawnui.net/articles/fluent-extensions.html), i love how .NET HotReload works with this approach. 

<TODO>
insert gif video of hotreload in action
</TODO>

And let's not forget about gestures:

```csharp
        public override ISkiaGestureListener ProcessGestures(SkiaGesturesParameters args, GestureEventProcessingInfo apply)
        {
            if (args.Type == TouchActionResult.Tapped)
            {
                Reset(); //reset our audio module to start analysing from scratch
                return this; //this means "who consumed the gesture"
            }
            return base.ProcessGestures(args, apply); //would return null or one of the possible children if they consume anything
        }
```

### Accessing Canvas DIrectly

We can override the main painting method of any `SkiaControl` to access the drawing surface:

```csharp

protected override void Paint(DrawingContext ctx)
    {
        base.Paint(ctx); //background + changed children, like our labels etc, will be painted automatically inside

        //we have total access to SkiaSharp canvas to draw EQ lines etc, all data we might need is:
        var canvas = ctx.Context.Canvas; //SkCanvas
        float scale = ctx.Scale; //density, how many pixels in one point
        SKRect destination = this.DrawingRect; //in pixels, after measure/arrange
            
        //an example of a usual SkiaSharp primitive:
        canvas.DrawOval(destination.Width/2.0f, destination.Height/2.0f, 15 * scale, 11 * scale, somePaint); //if we use scale it will look same size on any device/platform
    }

```

## Shaders Everywhere

One of the most interesting parts of SolTempo is the intensive use of shaders. Instead of basic  animations and the "usual" look, we rely on SkiaSharp v3 SKSL. This is also where the “single canvas” approach becomes useful, as we can make the whole UI elements tree be affected by shaders at will. 

As one might recall we already have been using shaders in [Filters Camera](https://github.com/taublast/ShadersCamera) and [ShadersCarousel](https://github.com/taublast/ShadersCarousel) apps, those gave us the a base for a confident use.

### Liquid Glass Backdrop

We are in 2026 so we couldn't pass on using a liquid glass-like effect. It gives the app a very distinct and modern look. Our menu bar needed this one badly.

<TODO>
zoomed pic of the menu bar
</TODO>

An obvious choice was then to reuse it for main audio modules too, and this defined the final look of the app. This all was implemented as a `GlassBackdropEffect` (a small wrapper around `SkiaShaderEffect`), attachable to any control, it provides a lot of customizable properties like corner radius, emboss/refraction, edge glow, tint and much more. Shader runs when the parent `SkiaBackdrop` control redraws.

I took a MIT licenced https://github.com/bergice/liquidglass shader that was deeply modified and resulted in a highly customisable visual effect.

```csharp
public class GlassBackdropEffect : SkiaShaderEffect
{
	public GlassBackdropEffect()
	{
		ShaderSource = @"Shaders\glass.sksl"; //shipped inside `Resources/Raw` MAUI app folder
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

### Animated Popups

In the mood of extensively using shaders I added entrance/exit shaders for popups that show help and settings. no more standart scale/fade transforms. In short we attach an entrance shader to show and an exit shader to hide the control. I created an `AnimatedPopup` class for that, and help and setting use it as base. I invite you to dig into the source code for a deeper look.

#### Shader transition when switching modules

This is a single-texture transition shader driven by a progress animator. At progress `0.0` we set the current control as shader texture source, at `0.5` (Midpoint) we set the second control as texture source to be used up to `1.0`, and we run a progress animator built into a `TransitionEffect`.

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

### Achievement Effect

When you sing a streak of correct notes for a double octave the app triggers encouraging effects. For the “Perfect Streak” we run an animated fullscreen `AchievementEffect` shader (and remove it when done):

<TODO>pic of shader in action </TODO>

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

There is also a simple “confetti helper” for the single octave achievement, try sing a full octave to trigger it 😄.

## Built-in Live Shader Editor

Writing SKSL shaders can be a trial-and-error process. To speed this up, I was using a built-in shader live editor that runs when the app is run on Windows. It opens when you press Settings button, i was attaching the shader to be edited via a `shaderGlass` variable:

```csharp
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
	}.Assign(out shaderGlass) //for dev shader editor
}
```

which was used later like this:

```csharp
    private void TappedSettings()
    {
        _settingsPopup?.Show();
#if DEBUG && WINDOWS
        OpenShaderEditor(shaderGlass);
#endif
    }
```

This means you can tweak the SKSL code inside the app, hit `Apply`, and instantly see the liquid glass background or the popup transition change in real-time to your changed SKSL code, no need to restart the app for that. I used a similar workflow for [Filters Camera](https://github.com/taublast/ShadersCamera) app.

## Additional Tricks

### Help popup content shipped as Markdown

App Help text required formatting, the **Help** popup loads its content from a Markdown file shipped inside the app package (`Resources/Raw/Markdown/help.en.md`). The popup just reads it at runtime once then sets a `SkiaRichLabel` property `Text` to markdown. Among other features this rather powerful control can parse and render markdown strings, including creating links.

<TODO>picture markdown with MAUI logos</TODO>

### Capping FPS on iOS (battery-friendly)

On iOS skia view is using Apple Metal for hardware accelerated rendering. This one can be very power consuming (and heat generating) when running at max fps. Since this is not a game but we still need to render constantly when sound comes at 48000 Hz rate on iPhone we capped fps:

```csharp
#if IOS // spare battery because apple metal is draining much
Super.MaxFps = 30;
#endif
```

It is a small change which makes a difference for a "realtime" app that can run for hours if you practice solfeggio.

## Final Thoughts

SolTempo being a compact playground for realtime audio analisys, visualization and SKSL shaders usage, we demonstrated that .NET MAUI has a rather extended usage limits. With SkiaSharp and the drawn approach you can ship apps that look and feel very far from the usual.

SolTempo is fully open-source, so if you want to dig in, clone it and start playing:

[SolTempo on GitHub](https://github.com/taublast/SolTempo)

Feel free to grab the code, experiment with the shader editor on Windows, and see what you can build.

Privacy note: SolTempo does not collect, store, or share personal data. Audio analysis happens locally on your device and all data stays on it.

## Links and Resources

* [SolTempo](https://github.com/taublast/SolTempo) - complete source code
* [AppStore](https://github.com/taublast/SolTempo) - install app on iOS
* [GooglePlay](https://github.com/taublast/SolTempo) - install app on Android
* [DrawnUI for .NET MAUI](https://github.com/taublast/DrawnUi) - the canvas rendering engine
* [SkiaSharp](https://github.com/mono/SkiaSharp) - the underlying 2D graphics library
* [SKSL documentation](https://skia.org/docs/user/sksl/) - Skia Shading Language reference

---

 *The author is available for consulting on drawn applications and custom controls for .NET MAUI. If you need help creating custom UI experiences, optimizing performance, or building entirely drawn apps, feel free to reach out.*
