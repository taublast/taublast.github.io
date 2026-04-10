---
layout: post
title: "AI-субтитры и обработка видео в реальном времени на .NET MAUI"
description: "Создаем мобильное приложение c фото- и видео-камерой на C# с использованием элемента SkiaCamera. SKSL шейдеры, AI-субтитры и наложение графики во время записи."
date: 2026-04-09 12:00:00 +0000
categories: [MAUI, DrawnUI, Camera, Video]
tags: [dotnetmaui, skiasharp, camera, video, audio, realtime, drawnui]
image: /assets/img/ru/camhi.jpg
---

## DrawnUi.Maui.Camera

Для захвата камеры в .NET MAUI есть хорошие варианты: [CommunityToolkit.Maui.Camera](https://learn.microsoft.com/en-us/dotnet/communitytoolkit/maui/views/camera-view), [MediaPicker](https://learn.microsoft.com/en-us/dotnet/maui/platform-integration/device-media/picker) и платформенное API.

Для особого класса задач, где необходимо обрабатывать превью и кадры, идущие в запись, есть пакет [DrawnUi.Maui.Camera](https://github.com/taublast/DrawnUi.Maui.Camera).

Лучше всего заходит для :

- Наложения эффектов/обработки превью и отправки кадров в AI/ML
- Обработки снятых фотографий перед записью в галерею
- Обработки видео-кадров в реальном времени
- Обработки аудио в реальном времени

<img src="https://taublast.github.io/assets/img/raceland.jpg" alt="Racebox Video Recording" width="800" />

*Опубликованное приложение .NET MAUI для Android записывает видео с оверлеем, кодируемым в реальном времени.*

Пакет предоставляет для работы элемент **SkiaCamera**, это - низкоуровневая камера с различными опциями вроде стабилизации, выбора аудио-режимов, форматов записи и пр., облаченная в оболочку от [DrawnUI](https://drawnui.net) для отрисовки и обработки графики с помощью [SkiaSharp](https://github.com/mono/SkiaSharp). Распространяется по лицензии MIT и одновременно поддерживает **iOS, MacCatalyst, Android и Windows**.

## В этой статье

Обсудим установку и инициализацию элемента, а также разберем приложение-пример, которое идет с git-репозиторием и демонстрирует следующее:

- оверлеи и эффекты, для превью, фото и видео, накладываемые в реальном времени
- генерацию субтитров в реальном времени на базе OpenAI, идут в итоговый видео-файл
- использование SKSL-шейдеров
- предзапись видео (pre-recording)
- работу с настройками камеры

Следующая статься покажет нам *как использовать SkiaCamera для распознавания лиц с помощью ML в реальном времени* и обсудит сценарии, где необходимо живые видео кадры в AI/ML.

Уже перед прочтением этой статьи вы собрать и запустить [приложение-пример](https://github.com/taublast/DrawnUi.Maui.Camera) на мобильном устройстве, а также на ПК Windows или Mac, если подключена камера.

<iframe src="https://taublast.github.io/assets/vids/formula.mp4" width="100%" height="547" frameborder="0"></iframe>

*Видео, записанное на iPhone с фильтром Noir, с наложенными в реальном времени эквалайзером и AI-субтитрами.*

Не пропустите [предыдущую статью](https://habr.com/ru/articles/1009382/), где мы разбирали как отдельно использовать аудио-поток от `SkiaCamera`.

## Настройка

Точка входа в документацию на английском языке для элемента, - это [README](https://github.com/taublast/DrawnUi.Maui.Camera) проекта.

Чтобы использовать `SkiaCamera` в приложении **.NET MAUI**, установите пакет, инициализируйте DrawnUI, а затем разместите камеру внутри аппаратно ускоренного Skia-холста.

### Установка:

```bash
dotnet add package DrawnUi.Maui.Camera
```

### Инициализация

Внутри `MauiProgram.cs`:

```csharp
builder.UseDrawnUi();
```

### Использование

Разместить на странице можно, например, так:

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

Важно:
* Держите контейнер стабильным: никаких строк `Auto`, никаких незаданных значений ширины или высоты без `Fill`.
* Чтобы ориентация записанного видео была корректной, зафиксируйте приложение или страницу камеры в портретном режиме. При этом UI всё равно может реагировать на поворот в ландшафт - и ниже мы именно так и сделаем.

### Ориентация UI

По умолчанию MAUI-приложения поворачивают UI вместе с устройством, но кодировщик видео ожидает стабильную ориентацию. Поэтому зафиксируйте всё приложение в портретном режиме на уровне платформы, а затем можно поворачивать отдельные элементы UI. Например, поворачивать иконки на кнопках, как у системных предустановленных приложений для камеры.

**Android** - `MainActivity.cs`:

```csharp
[Activity(Theme = "@style/Maui.SplashTheme",
    ScreenOrientation = ScreenOrientation.SensorPortrait,
	...
```

**iOS** - `Info.plist` (для публикации в сторе на iPad нам нужен ключик `UIRequiresFullScreen`, в противном случае AppStore потребовует от нас разблокировать Landscape):

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

В приложении-примере мы реагируем на поворот устройства, поворачивая иконки приложения - используем событие от `DrawnUI`:

```csharp
Super.RotationChanged += OnRotationChanged; //Super - это супервизор DrawnUI

 private void OnRotationChanged(object sender, int rotation)
 {
     var iconRotation = -NormalizeIconRotation(rotation);
     _buttonSettings.Rotation = rotation;
     _buttonFlash.Rotation = rotation;
     _buttonSelectCamera.Rotation = rotation;
 }
```

### Разрешения

Как задать нативные разрешения для каждой платформы подробно расписано описано в [README](https://github.com/taublast/DrawnUi.Maui.Camera), а для элемента мы можем опционально задать флаги, чтобы тот знал, какие именно надо запросить у пользователя при запуске:

```csharp
Camera.NeedPermissionsSet = NeedPermissions.Camera
    | NeedPermissions.Gallery
    | NeedPermissions.Microphone;
```

### Включение и выключение

Камерой управляет свойство `IsOn`, можно забайндить. Включать можно в нужный момент, например, - после первой отрисовке холста:

```csharp
// эвент также можно использовать и в XAML
Canvas.WillFirstTimeDraw += (sender, context) =>
{
	if (CameraControl != null)
	{
		//не будем тормозить первую отрисовку, чуток отложим
		Tasks.StartDelayed(TimeSpan.FromMilliseconds(500), () =>
		{
			CameraControl.IsOn = true;
		});
	}
};
```

Если под камеру открывается отдельная страница, то `IsOn` можно переключать при событиях навигации, будет зависеть от вашей реализации. Я рекомендую для этого пакет [LightNavigation](https://github.com/taublast/LightNavigation), там удобно реагировать на `OnTopmost()` - можно включать, `OnCovered` - выключаем, `OnRemoved` - диспозим. Можно открывать в попапах - пакет [FastPopups][https://github.com/taublast/FastPopups] в помощь.

Когда приложение уходит в фон, камера автоматически приостанавливается и восстанавливается при возврате, не меняя значение `IsOn`, руками ничего делать не придется.

`SkiaCamera` рисует дочерний эелемент типа `SkiaImage`, который принимает изображения от нативной камеры на GPU поверхностях. Этот контрол доступен через свойство `Display`, соответственно, мы можем влиять на верхне-уровневое отображение превью как на обычный `SkiaImage` - блюрить, накладывать эффекты итп. Это - еще  отдельно от низко-уровневой обработки изображений для превью, об этом - далее.

## Приложение-пример

Пример из репозитория отрабатывает почти весь набор настроек камеры, а также некоторые примеры процессинга данных: аудио-визуализаторы, OpenAI-субтитры, SKSL-фильтры. 

UI описан C#-кодом, без XAML, - отдельный пример для XAML и MVVM лежит в другом репозитории: [DrawnUI for .NET MAUI Demo](https://github.com/taublast/DrawnUi.Maui.Demo).

UI состоит из трёх основных частей:

* Верхний заголовок для быстрого переключения между Photo и Video, элементы управления субтитрами.
* Оверлей посередине, для быстрых действий с камерой, - кнопки записи и прочее.
* Нижний выезжающий "ящик" с детальными настройками камеры, разбитыми на три секции: `Input` (Ввод), `Processing` (Обработка) и `Output` (Экспорт).

<iframe src="https://taublast.github.io/assets/vids/videofilters.mp4" width="100%" height="547" frameborder="0"></iframe>

*Переключение видеофильтров на iPhone, снимающего экран ноутбука проигрывающего YouTube-видео.*

- Раздел `Input` управляет выбором камеры, форматом захвата и режимом.
- `Processing` отвечает за realtime-часть: мониторинг и визуализация аудио, прочий процессинг.
- `Output` управляет экспортом, что и как будет записано: аудио/видео-переключатели, настройки предзаписи и пр..

В нашем примере `SkiaCamera` для удобства наследуется в классе `AppCamera` и по умолчанию настроена на запись с обработкой:

```csharp
public partial class AppCamera : SkiaCamera
{
	public AppCamera()
	{
		NeedPermissionsSet = NeedPermissions.Camera | NeedPermissions.Gallery | NeedPermissions.Microphone;
		InjectGpsLocation = true;

		UseRealtimeVideoProcessing = true; //ключевой момент
		VideoQuality = VideoQuality.Standard;
		EnableAudioRecording = true;

		ProcessFrame = OnFrameProcessing;
		ProcessPreview = OnFrameProcessing;
	}
}
```

`UseRealtimeVideoProcessing = true` - ключевой переключатель, без него превью и запись идут кратчайшим путем.
С ним каждый кадр проходит через Skia до кодирования, и всё, что нарисовано в `ProcessFrame`, становится частью файла. Хук `ProcessPreview` работает для режима предпросмотра. Важный момент, когда идет запись при включенном процессинге, в превью идет уменьшенный кадр который прошел обработку для записи видео, по принципу что видишь, то и записываешь.

Оба обработчика получают `DrawableFrame`: целевой `SKCanvas`, исходный `SKImage` с камеры, текущий `Scale` и флаг `IsPreview`. Флаг позволяет при необходимости по-разному рендерить превью и запись. В нашем примере одно общее overlay-дерево работает для обоих режимов: EQ виден везде, а captions только меняют позицию - в preview и в recording.

Изображения приходят в эти колбеки от виртуальных методов `RenderPreviewForProcessing` и `RenderFrameForRecording`, которые создают холсты для дальнейшей работы. Вы увидите ниже, что мы использовали эти методы в нашем приложении, чтобы наложить видео-фильтры с использованием SKSL-шейдеров.

## Запись видео

Управление записью простое:

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

Если видео-запись завершена, - итоговый файл переносится в галерею:

```csharp
private async void OnVideoRecordingSuccess(object sender, CapturedVideo capturedVideo)
{
	var publicPath = await CameraControl.MoveVideoToGalleryAsync(capturedVideo, MauiProgram.Album);
	_lastSavedVideoPath = publicPath;
}
```

Есть и сценарий отмены, в основном полезный для режима предзаписи:

```csharp
await CameraControl.StopVideoRecording(true); //отмена записи
```

Он очищает полученную видео-запись вместо её финализации.

## Предзапись

Иногда при на жатии на кнопку записи мы не успеваем за моментом. Что-то произошло, мы нажали REC, - всё, что было до нажатия, уже потеряно.

Предзапись решает проблему за счёт постоянно работающего в памяти кольцевого буфера. Видео бесконечно и циклично идет память, ее затраты минимальны: старые кадры вытесняются с хвоста. Когда же мы запустим реальную запись, камера приклеит к началу финального файла несколько секунд, предшествовавших записи. В итоге финальное видео содержит момент, запустившй запись и несколько секунд до него.

Подходит для спорта, семейных моментов, съемки дикой природы - любых сценариев, где невозможно точно предсказать начало действия.

Представим, режим камеры безопасности, как AI или детектор движения запускает основную запись, а предзапись гарантирует, что будут зафиксированны и несколько секунд до события. Без постоянной записи на диск гигабайт пустого материала.

Включить:

```csharp
CameraControl.EnablePreRecording = true;
CameraControl.PreRecordDuration = TimeSpan.FromSeconds(5);
```

Первый вызов `Start()` запускает предзапись. Второй вызв запустит основную запись, а секунды перед ней уже сохранены. Если нужно отменить и выбросить материал вместо сохранения:

```csharp
await CameraControl.StopVideoRecording(true); // true = без сохранения
```

И `IsPreRecording`, и `IsRecording` являются bindable-свойствами, так что состояние кнопки записи, подписи и анимации можно связать напрямую без дополнительной логики.

Полный разбор смотрите в [PreRecording.md](https://github.com/taublast/DrawnUi.Maui.Camera/blob/main/PreRecording.md).

## SKSL-видеофильтры

Мы применяем видеофильтры, реализованные на SKSL-шейдерах, к превью, снятому фото и записанному видео.

Поскольку каждый кадр проходит через Skia до кодирования, SKSL-эффекты можно применять к записываемому видео прямо в реальном времени. Итоговый MP4 уже будет содержать отфильтрованные кадры, без отдельной постобработки.

В sample app для этого есть вспомогательное свойство `VideoEffect` у `AppCamera`:

```csharp
CameraControl.VideoEffect = ShaderEffect.Movie;
```

`AppCamera` переопределяет и `RenderPreviewForProcessing`, и `RenderFrameForRecording`, чтобы применить выбранный shader effect до передачи кадров в превью или энкодер. Эффект один и тот же, путь один и тот же, меняется только target.

Переключитесь на `ShaderEffect.None` - и вы снова получаете чистый захват. Переключите эффект прямо во время сессии - и изменение фильтра попадёт в файл с этого момента.

Снятая фотография тоже обрабатывается до сохранения в галерею на GPU-потоке:

```csharp
private async void OnCaptureSuccess(object sender, CapturedImage captured)
{
	if (CameraControl.UseRealtimeVideoProcessing && CameraControl.VideoEffect != ShaderEffect.None)
	{
		var imageWithEffect = await CameraControl.RenderCapturedPhotoAsync(captured, null, image =>
		{
				var shaderEffect = new SkiaShaderEffect()
				{
					ShaderSource = ShaderEffectHelper.GetFilename(CameraControl.VideoEffect),
				};
				image.VisualEffects.Add(shaderEffect);
		}, true);

		captured.Image.Dispose();
		captured.Image = imageWithEffect;
	}

	SaveFinalPhotoInBackground(captured);
}
```

Это код из `MainPage.OnCaptureSuccess` в sample app.

В sample уже есть несколько SKSL-пресетов, с которыми можно поиграть, а добавить свои - это просто написать обычный SKSL fragment shader.

Shader-ассеты лежат в sample по пути `src/Sample/Resources/Raw/Shaders`.

## Рисованный оверлей

Виртуальные методы `RenderPreviewForProcessing` и `RenderFrameForRecording` подготавливают `SKCanvas`, который затем передаётся в колбэки `ProcessPreview` или `ProcessFrame` - там мы уже рисуем поверх кадров всё что нужно.

Внутри колбэков, конечно, можно пользоваться и обычными примитивами SkiaSharp: `SKCanvas.DrawText`, `DrawRect` и другими.

Для сложной графики оверлеи удобно собирать из DrawnUI-layout'ов.

Наш overlay содержит два видимых модуля:

- панель аудиовизуализатора в правом верхнем углу
- панель субтитров, отрисованную через `SkiaRichLabel`

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

Для эквалайзера здесь используется кеш ImageDoubleBuffered - чтобы не тормозить рендеринг кадра. Cache просчитывает и рисует результат в фоне, а на холст каждый раз быстро выводится последний готовый растр.

EQ-панель стоит одинаково и в preview, и в recording. С captions иначе: во время preview HUD занимает нижнюю часть экрана, и субтитры внизу просто бы перекрылись элементами управления. Поэтому в sample панель субтитров центрируется по вертикали при отрисовке preview-кадров, а для записываемых возвращается к низу.

Где это лежит в sample app:

- Сборка overlay и visual effects для captions: `src/Sample/UI/FrameOverlay.cs`
- Рендеринг overlay и масштабирование относительно данных кадра: `src/Sample/UI/AppCamera.cs` (`DrawOverlay` и `OnFrameProcessing`)
- Подключение captions feed и транскрипции: `src/Sample/UI/MainPage.cs`
- Rolling-window state и таймеры субтитров: `src/Sample/Services/RealtimeCaptionsEngine.cs`

В `AppCamera.DrawOverlay` мы адаптируем и режим, и масштаб.
`layout.AdaptLayoutToMode(frame.IsPreview)` переключает размещение captions между preview и recording, а `overlayScale` вычисляется из `frame.Scale` и формата камеры, чтобы один и тот же layout оставался визуально стабильным и в превью, и в закодированных кадрах.

>Чтобы узнать расположение контрола камеры на SkiaSharp-холсте, можно использовать свойство камеры `SKRect DrawingRect`. Если свойство `Aspect` выставлено не в `Fill`, а в `Fit`, вокруг реального кадра могут появиться "чёрные полосы". Тогда можно использовать свойство `SKRect DisplayRect`, чтобы получить точную область, где масштабированное превью действительно рисуется на холсте.

## AI-субтитры речи

В одной из следующих статей будем детектировать лица в реальном времени, а сегодня давайте транскрибировать речь с помощью модели **OpenAI Whisper** и кодировать субтитры в финальное видео прямо в реальном времени.
Сервис лежит в `src/Sample/Services/OpenAi/OpenAiAudioTranscriptionService.cs`.

<img src="https://taublast.github.io/assets/img/captions.jpg" alt="Nick Kovalsky" width="350" />

*Автор тестирует субтитры на Android, кадр из итогового видео с debug-информацией.*

В [предыдущей статье](../SolTempo/) мы подробно разбирали, как получать аудио из `SkiaCamera`. Подключим транскрипцию так:

```csharp
CameraControl.AudioSampleAvailable += (data, rate, bits, channels)
    => OnAudioCaptured(data, rate, bits, channels);
```

Затем отправляем входящий PCM в сервис:

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

Чтобы включить AI-субтитры в собранном sample, откройте `src/Sample/Secrets.cs` и вставьте свой OpenAI-ключ:

```csharp
public static string OpenAiKey = "sk-...";
```

Без ключа sample нормально собирается и запускается, просто AI-субтитры будут отключены.

Полученный текст мы пробрасываем в frame overlay так:

```csharp
_captionsEngine.CaptionsChanged += spans =>
	MainThread.BeginInvokeOnMainThread(()
        => _previewFrameOverlay.SetCaptions(spans));
```

Поскольку все видеокадры приходят к нам в виде SkiaSharp-холста, captions удобно рисовать через DrawnUI:

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

Субтитрами управляет `RealtimeCaptionsEngine`. Каждый абзац хранится до тех пор, пока либо не придёт более новый, либо не истечёт таймер последнего добавленного абзаца. Когда таймер последнего абзаца всё-таки истекает, мы [применяем шейдер](https://drawnui.net/articles/shaders.html), чтобы красиво растворить его:

```csharp
void AnimateOut(SkiaControl control)
{
	var animExit = new AnimatedShaderEffect()
	{
		UseBackground = PostRendererEffectUseBackgroud.Once,
		ShaderSource = MauiProgram.ShaderRemoveCaption,
		DurationMs = 400
	};

	animExit.Completed += (s, e) =>
	{
		control.VisualEffects.Remove(animExit);
		control.DisposeObject(animExit);
		control.IsVisible = false;
	};

	control.VisualEffects.Add(animExit);
	animExit.Play();
}
```

Полная версия в `FrameOverlay.cs` ещё и отменяет уже запущенную exit-анимацию перед стартом новой, чтобы быстрые ON/OFF-переключения не наслаивали эффекты на панель.

Поскольку один и тот же overlay используется и для preview, и для recording, captions остаются видимыми вживую и сразу вшиваются в финальное видео без второго прохода экспорта. Единственная разница в layout - где именно они стоят: по центру во время preview, чтобы их не перекрывал HUD приложения, и ближе к низу в записанном результате.

## GPS и метаданные

Включить геотегирование можно одним флагом:

```csharp
InjectGpsLocation = true;
```

Вызывайте `RefreshGpsLocation`, когда камера включается, чтобы координаты были свежими до начала записи:

```csharp
if (CameraControl.InjectGpsLocation)
    _ = CameraControl.RefreshGpsLocation();
```

После этого GPS встраивается автоматически - в контейнер MP4 для видео и в EXIF для фотографий. Координаты не нужно подставлять вручную, они уже будут на месте. Учтите только, что их отображение зависит от галереи или плеера, который читает файл.

Для видео можно также проставить в метаданные контейнера поля брендинга:

```csharp
// CameraControl.RecordingSuccess += OnRecordingSuccess;
private async void OnRecordingSuccess(object sender, CapturedVideo capturedVideo)
{
	capturedVideo.Meta.Vendor = "Me";
	capturedVideo.Meta.Software = "My App";
	var publicPath = await CameraControl.MoveVideoToGalleryAsync(capturedVideo, MauiProgram.Album);
}
```

Для фотографий доступен полный набор EXIF: ISO, выдержка, диафрагма, фокусное расстояние, ориентация, GPS, timestamp, software, vendor, model. Модель `Metadata` даёт доступ ко всему этому ещё до сохранения:

```csharp
// CameraControl.CaptureSuccess += OnCaptureSuccess;
private async void OnCaptureSuccess(object sender, CapturedImage captured)
{
	captured.Meta.Software = "My App";
	var path = await CameraControl.SaveToGalleryAsync(captured, "MyAppAlbum");
}
```

## Заключение

Если вашему приложению нужна брендированная запись, AI-assisted media, спортивная телеметрия, guided capture, субтитры или аудиореактивные оверлеи, этот контрол рассчитан именно на такой класс задач.

Если соберёте на нём что-то интересное, обязательно дайте знать. Буду рад увидеть, что эта работа оказалась полезной другим. PR тоже приветствуются.

## Ссылки и ресурсы

- [DrawnUi.Maui.Camera](https://github.com/taublast/DrawnUi.Maui.Camera) - репозиторий контрола SkiaCamera с sample app и документацией
- [DrawnUi.Maui.Demo](https://github.com/taublast/DrawnUi.Maui.Demo) - пример использования SkiaCamera для фотографий с XAML/MVVM
- [Real-Time Camera Filters](../FiltersCamera/) - более ранняя статья о применении SKSL-шейдеров со SkiaCamera и примером приложения
- [Building a Real-time Audio Processing App](../SolTempo/) - более ранняя статья об использовании SkiaCamera для аудио с примером приложения
- [DrawnUI for .NET MAUI](https://github.com/taublast/DrawnUi) - OSS-репозиторий движка рендеринга, на котором построен этот контрол
- [SkiaSharp](https://github.com/mono/SkiaSharp) - базовая 2D-графическая библиотека, благодаря которой всё это стало возможным

---

*Автор открыт к консультациям и работает над drawn-приложениями и кастомными контролами для .NET MAUI. Если вам нужна помощь с нестандартным UI, оптимизацией производительности или созданием drawn mobile apps, смело обращайтесь.*