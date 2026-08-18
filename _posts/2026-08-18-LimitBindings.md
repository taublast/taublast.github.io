---
layout: post
title: "When Incoming Data Is Faster Than Your Eyes"
description: "Limit .NET MAUI bindings update, while keeping incoming data at full speed for a smooth app"
date: 2026-08-18 08:00:00 +0000
categories: [MAUI]
tags: [dotnetmaui, mvvm, performance, binding, sensors, throttling]
image: /assets/img/limi2.jpg
---

This post came out from a real app case I had, Racebox, where a Bluetooth device was sending data 20 times per second. The UI was mostly defined in XAML and updated from bindings on the UI thread. And you might guess when data started arriving at that rate the app interactions stopped being smooth. Visually you would not tell until trying to swipe, animate, navigate and similar. The UI thread was a little to busy, and that was visible to users: must admit that I was not noticing this much until I started testing this scenario on some mid-low range Android devices.

To fix this, I decided to cut the frequency of UI updates from bindings, while still keeping data processing at full speed. The obvious solution seemed to be to cut how often the bindings raise the `PropertyChanged` event.

First I limited it to 10Hz, but displayed float numbers like "1.234" did not change the figures after the dot fast enough for a nice dynamic effect. So I found 12Hz to be the best rate for such a case: limited updates, and still looking very dynamic.

Your case might have an even more aggressive incoming data rate, and yet this simple solution will work for any .NET MAUI app.

## Problem and solution

Every time a property setter raises `PropertyChanged`, MAUI does real work on the main thread. It evaluates the binding, converts the value, and marks the control for layout and redraw. And then the native UI tries to match up: the handler pushes the new value into the platform view, which measures, arranges and repaints itself.

For 20 packets per second and 30 visible properties it's 600 UI updates triggered every second. And most of them produce the same pixels as the pass before.

The data rate is not the problem. The number of times we invalidate the UI is.

The solution could be to let the data run at its own speed: collect the names of what changed, then signal the UI on a schedule, in one batch.

We could store the property names which will update the UI via bindings inside a custom `INotifyPropertyChanged` ViewModel, which would allow the UI update rate limiting.

For example, in a usual ViewModel a property could be defined like this:

```csharp
 private int _lastMeasureResultCode;
 public int LastMeasureResultCode
 {
     get { return _lastMeasureResultCode; }
     set
     {
         if (_lastMeasureResultCode != value)
         {
             _lastMeasureResultCode = value;
             OnPropertyChanged(); // triggers event and bindings propagation
         }
     }
 }
```
That `OnPropertyChanged` would kick in our UI bindings which we would want to limit. So we would replace `OnPropertyChanged` with a nice `SmartOnPropertyChanged` and go from here, sitting inside our custom ViewModel:

```csharp
 [MethodImpl(MethodImplOptions.AggressiveInlining)]
 private void SmartOnPropertyChanged([CallerMemberName] string propertyName = null)
 {
     if (string.IsNullOrEmpty(propertyName))
         return;

     lock (lockRaiseProperties)
     {
         RaiseProperties.Add(propertyName);
     }
 }

     HashSet<string> RaiseProperties = new HashSet<string>();
```

Now the setter would no longer touch the UI, it only writes the property *name* into a set, and returns. The set also removes duplicates for us: if speed changes twenty times before the next flush, `RaiseProperties` still holds one entry, `"DisplaySpeed"`.

Now something must decide *when* to empty that set, and something must raise the events without holding the lock. Here is the flow first, and the whole class right after.

## The ViewModel

This is the path of a property change we would implement:

1. A setter runs on the data thread and calls `SmartOnPropertyChanged`. The name lands in `RaiseProperties`. Nothing else happens, the thread is free again.
2. When the packet is processed, the code calls `UpdateUi`. That is the gate.
3. If the last flush is older than the interval, `ApplyUpdateUi` runs right away on the main thread. If not, a timer is armed for the time that is left, and `_updateUiPending` remembers that data is waiting.
4. `ApplyUpdateUi` recomputes the display properties, copies the names out of the set under the lock, clears it, and raises `PropertyChanged` for each name outside the lock.
5. `RescheduleUpdateUi` checks whether new data arrived while we were flushing. If yes, back to step 2.

That pending flag in step 3 is what makes it a gate and not a plain "ignore it if too soon" throttle. A plain throttle drops the last packet: when data stops right after a rejected call, the screen keeps a stale value.

Here it is, cleaned up as a base class, so you can inherit from it:

```csharp
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.CompilerServices;
using System.Threading;

public abstract class ThrottledViewModel : INotifyPropertyChanged, IDisposable
{
    public event PropertyChangedEventHandler PropertyChanged;

    /// <summary>Upper limit for UI refreshes per second.</summary>
    public static int UpdateUiRateLimitHz = 12;

    HashSet<string> RaiseProperties = new();
    object lockRaiseProperties = new();
    string[] _raiseBuffer = new string[64];   // main thread only

    readonly object _updateUiRateLimitSync = new();
    bool _updateUiPending;
    bool _updateUiDispatchQueued;
    long _lastUpdateUiTimestamp;
    Timer _updateUiTimer;

    static readonly Dictionary<string, PropertyChangedEventArgs> _args = new();

    /// <summary>Recompute display properties here. Their setters call SmartOnPropertyChanged.</summary>
    protected abstract void UpdatePropertiesInternal();

    /// <summary>Call from setters instead of OnPropertyChanged. Safe from any thread.</summary>
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    protected void SmartOnPropertyChanged([CallerMemberName] string propertyName = null)
    {
        if (string.IsNullOrEmpty(propertyName))
            return;

        lock (lockRaiseProperties)
        {
            RaiseProperties.Add(propertyName);
        }
    }

    /// <summary>Call as often as data arrives.</summary>
    public void UpdateUi()
    {
        bool runNow = false;
        TimeSpan due = TimeSpan.Zero;
        Timer timer = null;

        lock (_updateUiRateLimitSync)
        {
            _updateUiPending = true;

            if (_updateUiDispatchQueued)
                return;

            var rateLimitHz = Math.Clamp(UpdateUiRateLimitHz, 1, 30);
            var minInterval = TimeSpan.FromSeconds(1.0 / rateLimitHz);
            var elapsed = _lastUpdateUiTimestamp == 0
                ? minInterval
                : Stopwatch.GetElapsedTime(_lastUpdateUiTimestamp);

            _updateUiDispatchQueued = true;

            if (elapsed >= minInterval)
            {
                _updateUiPending = false;
                runNow = true;
            }
            else
            {
                _updateUiTimer ??= new Timer(_ =>
                    MainThread.BeginInvokeOnMainThread(TimerUpdateUi),
                    null, Timeout.InfiniteTimeSpan, Timeout.InfiniteTimeSpan);

                due = minInterval - elapsed;
                timer = _updateUiTimer;
            }
        }

        if (runNow)
        {
            MainThread.BeginInvokeOnMainThread(() => { ApplyUpdateUi(); RescheduleUpdateUi(); });
            return;
        }

        timer?.Change(due, Timeout.InfiniteTimeSpan);
    }

    void TimerUpdateUi()
    {
        bool run;
        lock (_updateUiRateLimitSync)
        {
            run = _updateUiPending;
            _updateUiPending = false;
        }

        if (run)
            ApplyUpdateUi();

        RescheduleUpdateUi();
    }

    void RescheduleUpdateUi()
    {
        bool again;
        lock (_updateUiRateLimitSync)
        {
            _updateUiDispatchQueued = false;
            again = _updateUiPending;
        }

        if (again)
            UpdateUi();
    }

    void ApplyUpdateUi()
    {
        try
        {
            UpdatePropertiesInternal();

            int raiseCount;
            lock (lockRaiseProperties)
            {
                raiseCount = RaiseProperties.Count;
                if (raiseCount > _raiseBuffer.Length)
                    _raiseBuffer = new string[raiseCount * 2];
                RaiseProperties.CopyTo(_raiseBuffer);
                RaiseProperties.Clear();
            }

            for (int i = 0; i < raiseCount; i++)
                RaisePropertyChanged(_raiseBuffer[i]);
        }
        finally
        {
            lock (_updateUiRateLimitSync)
            {
                _lastUpdateUiTimestamp = Stopwatch.GetTimestamp();
            }
        }
    }

    // private on purpose: _args is a plain Dictionary and this runs on the main thread only
    void RaisePropertyChanged(string name)
    {
        if (!_args.TryGetValue(name, out var args))
        {
            args = new PropertyChangedEventArgs(name);
            _args[name] = args;
        }
        PropertyChanged?.Invoke(this, args);
    }

    public void Dispose()
    {
        Timer timer;
        lock (_updateUiRateLimitSync)
        {
            timer = _updateUiTimer;
            _updateUiTimer = null;
        }
        timer?.Dispose();
    }
}
```

## Details worth naming

- Events are raised **outside** the lock. Binding evaluation and layout invalidation happen during the raise. If the lock were still held, the data thread would wait for all of it, on every single property it wants to mark. Here it waits only for a copy of a few string references.
- `_raiseBuffer` is reused: it grows once, then stops allocating.
- The `PropertyChangedEventArgs` are cached per name, for the same reason. That cache is static and lives as long as the app, bounded by the number of distinct property names. It and the buffer are touched from the main thread only, which is why `RaisePropertyChanged` is private: a subclass calling it from a background thread would corrupt the dictionary.
- The timer is created once and rearmed with `Change`, so a busy stream does not allocate a timer per packet.
- Time comes from `Stopwatch`, which is monotonic. `DateTime.Now` can jump when the clock changes. `Stopwatch.GetElapsedTime` needs .NET 7 or newer.
- The timestamp is written in `finally`, after the work, so the gate keeps a minimum gap between flushes. Written at the start instead, you get a fixed rate, and a long flush can be followed immediately by the next one.

## Usage example

```csharp
public class DeviceViewModel : ThrottledViewModel
{
    string _displaySpeed = "-";
    public string DisplaySpeed
    {
        get => _displaySpeed;
        set
        {
            if (value == _displaySpeed)
                return;
            _displaySpeed = value;
            SmartOnPropertyChanged();
        }
    }

    int _packetsReceived;
    public int PacketsReceived
    {
        get => _packetsReceived;
        set
        {
            if (value == _packetsReceived)
                return;
            _packetsReceived = value;
            SmartOnPropertyChanged();
        }
    }

    protected override void UpdatePropertiesInternal()
    {
        SetProperty_DisplaySpeed();
        // ...the rest of the visible properties
    }

    // raised by the processor after each decoded packet, off the UI thread
    void OnDataProcessed(object sender, EventArgs e)
    {
        PacketsReceived++;   // rough counter, marks the name and returns, no UI work here
        UpdateUi();          // gated
    }
}
```

There are two ways a property gets marked, and both are used above.

`PacketsReceived` is set straight from the data thread. The setter only adds a string to the set and returns, so the decoding thread is never blocked by binding work. This is the case the lock is built for: without it, twenty packets per second would each be waiting on the main thread.

`DisplaySpeed` is set from `UpdatePropertiesInternal`, which already runs on the main thread inside the flush. Use this one for values that need formatting, so the string is built at the limited rate and not at the data rate.

XAML does not change at all, bindings work as usual. The data path is untouched too: packets are decoded and processed at full speed, and everything that records, measures or exports keeps reading current values. Only `UpdateUi` is gated.

## Skipping work that changes nothing

`UpdatePropertiesInternal` runs every display property on every flush, and most of them build a string. Keep the last value and compare before formatting:

```csharp
private double _cacheDisplaySpeed = double.NaN;

void SetProperty_DisplaySpeed()
{
    var value = Math.Round(Processor.SpeedOutput, 1);

    if (value.Equals(_cacheDisplaySpeed))
        return;

    _cacheDisplaySpeed = value;
    DisplaySpeed = $"{value:0.0}";   // setter calls SmartOnPropertyChanged
}
```

Round first, then compare: 42.41 and 42.44 both render as `"42.4"`, so there is no reason to build that string twice.

The `NaN` starting value is deliberate. `double.NaN.Equals(double.NaN)` returns `true`, while `NaN == NaN` returns `false`. Using the instance `Equals` means the first real value always passes the check, and later `NaN` readings do not spam the UI.

## What this does not do

- A displayed value can be up to one interval old. For a speed readout that is fine. For a countdown that must land on an exact moment, it is not.
- The flush is paced by the clock, not by the render frame. It does not cause extra redraws, but the work does share the main thread with rendering.
- Each viewmodel gates itself. Two of them on one page flush at unrelated moments.
- The set saves the *notification*, not the computation. If your formatters are expensive, guard each one like the speed example above.

## Conclusion

So if your incoming data rate is high, you can still keep MAUI bindings and limit how often they reach the UI, for a more fluid app.

As said above, `UpdateUiRateLimitHz = 12` was the rate that worked for my case, with numbers showing one figure after the dot. Below about 10 the last digit started to look like it was stuttering. Above 20 you are paying for frames a person cannot read.

We might one day have a .NET MAUI `BindableObject` provide similar logic out of the box. Something like a new property `NotifyPropertyChangedMode` with `Default`, `Limited` (this article example) and `Manual` (storing changes, firing manually upon user call) enum values. Why not.

If you try this in your own app and it helped, I would be glad to hear your story or any feedback in the comments.

---

*The author is available for consulting and development work on mobile apps and custom controls for .NET. If you need help with custom UI, native interop, or performance tuning, feel free to [reach out](/about).*

