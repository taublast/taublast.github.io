---
layout: post
title: "AI-субтитры и обработка видео в реальном времени на .NET MAUI"
description: "Как создать мобильное приложение c фото- и видео-камерой на C# с использованием элемента SkiaCamera: SKSL шейдеры, AI-субтитры и наложение графики во время записи."
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

Обсудим установку и инициализацию элемента `SkiaCamera`, разберем приложение-пример, которое идет вместе с репозиторием и демонстрирует:

- Оверлеи и эффекты, для превью, фото и видео, накладываемые в реальном времени
- Генерацию субтитров в реальном времени на базе OpenAI, идут в итоговый видео-файл
- Использование SKSL-шейдеров
- Предзапись видео (pre-recording)
- Работу с настройками камеры

В следующей статье мы посмотрим *как использовать `SkiaCamera` для распознавания лиц с помощью ML в реальном времени* и обсудим сценарии, при которых необходимо слать поток видео кадров в AI/ML.

Уже перед прочтением этой статьи вы можете собрать и запустить [приложение-пример](https://github.com/taublast/DrawnUi.Maui.Camera) на мобильном устройстве, а также на ПК Windows или Mac, если подключена камера.

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
* Держите контейнер стабильным: никаких `Auto` для сеток, никаких незаданных значений ширины или высоты без `Fill`.
* Чтобы ориентация записанного видео была корректной, зафиксируйте приложение или страницу камеры в портретном режиме. При этом ваш UI всё равно может реагировать на поворот в ландшафт, ниже мы именно так и сделаем.

### Ориентация UI

По умолчанию MAUI-приложения поворачивают UI вместе с устройством, но кодировщик видео ожидает стабильную ориентацию. Поэтому зафиксируйте приложение в портретном режиме на уровне платформы, позже сможете поворачивать отдельные элементы UI. 

**Android** - `MainActivity.cs`:

```csharp
[Activity(Theme = "@style/Maui.SplashTheme",
    ScreenOrientation = ScreenOrientation.SensorPortrait,
	...
```

**iOS** - `Info.plist` (для публикации в сторе на iPad нам нужен ключ `UIRequiresFullScreen`, в противном случае AppStore потребовует от нас разблокировать Landscape):

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

В приложении-примере мы реагируем на поворот устройства и поворачиваем иконки приложения на кнопках, как это делаю системные предустановленные приложений для камеры. Используем событие от `DrawnUI`:

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

Как задать нативные разрешения для каждой платформы подробно описано в [README](https://github.com/taublast/DrawnUi.Maui.Camera), а для элемента мы можем опционально задать флаги, чтобы он знал, какие именно надо запросить у пользователя при запуске:

```csharp
Camera.NeedPermissionsSet = NeedPermissions.Camera
    | NeedPermissions.Gallery
    | NeedPermissions.Microphone;
```

### Включение и выключение

Камерой управляет свойство `IsOn`, можно забайндить. Включать можно в нужный момент, например, - после первой отрисовки холста:

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

Если под камеру открывается отдельная страница, то `IsOn` можно переключать при событиях навигации, будет зависеть от вашей реализации. Я рекомендую для этого пакет [LightNavigation](https://github.com/taublast/LightNavigation), там удобно реагировать на `OnTopmost` - можно включать, `OnCovered` - выключаем, `OnRemoved` - диспозим. Можно открывать в попапах - пакет [FastPopups](https://github.com/taublast/FastPopups) в помощь.

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

Иногда при на жатии на кнопку записи мы не успеваем за моментом. Что-то произошло очень быстро, мы нажали REC, - но всё, что было до нажатия, потеряно.

Предзапись решает проблему за счёт постоянно работающего в памяти кольцевого буфера. Видео бесконечно и циклично идет в память, ее затраты минимальны: старые кадры вытесняются с хвоста. Когда мы запустим реальную запись, камера приклеит к началу финального файла несколько секунд, предшествовавших записи. В итоге финальное видео содержит момент начала записи и несколько секунд до него.

Подходит для спорта, семейных моментов, съемки дикой природы - любых сценариев, где невозможно точно предсказать начало действия.

Представим, режим камеры безопасности: AI или детектор движения запускают запись, а предзапись гарантирует, что будут зафиксированны и несколько секунд до события. В итоге у нас - видео с причиной и следствием, без нужды постоянной записи на диск пустого материала.

Включить:

```csharp
CameraControl.EnablePreRecording = true;
CameraControl.PreRecordDuration = TimeSpan.FromSeconds(5);
```

Первый вызов `Start()` запускает предзапись. Второй вызов запустит основную запись, - секунды перед ней уже сохранены. Если нужно отменить идущую запись или предзапись без сохранения:

```csharp
await CameraControl.StopVideoRecording(true); // true = без сохранения
```

И `IsPreRecording`, и `IsRecording` являются bindable-свойствами, так что состояние кнопки записи, подписи и анимации можно связать напрямую без дополнительной логики.

Полный разбор смотрите в [PreRecording.md](https://github.com/taublast/DrawnUi.Maui.Camera/blob/main/PreRecording.md).

## SKSL-видеофильтры

К предпросмотру, снятому фото и записываемому видео мы можем применять видео фильтры на выбор. Фильтры описаны SKSL-шейдерами. я взял их из своего существующего проекта, описанного в одной из предыдущих статей на английском языке: [Камера с фотофильтрами](https://taublast.github.io/posts/FiltersCamera/).

Поскольку каждый кадр при видеозаписи проходит через наши руки до кодирования, мы можем применять эффекты и любую обработку к записываемому видео в реальном времени. Итоговый MP4 будет содержать обработанные кадры, не нуждающиеся в постобработке.

Для удобства переключения фильтрв в приложении-примере мы ввели вспомогательное свойство `VideoEffect` для  `AppCamera`. Становится легко переключаеть фильтры, например:

```csharp
CameraControl.VideoEffect = ShaderEffect.Movie;
```

`AppCamera` переопределяет виртуальные методы `RenderPreviewForProcessing` и `RenderFrameForRecording`, чтобы отрисовывать изображение кадра холсте с `SKPaint` у которого установлен выбранный нами шейдер. Эти методы закроют нам отрисовку шейдерами как превью, так и снимаемое видео. 

Снятая же фотография обрабатывается до сохранения в галерею следующим образом, в GPU-потоке:

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
		}, true); //true - использовать аппаратное ускорение

		captured.Image.Dispose();
		captured.Image = imageWithEffect;
	}

	SaveFinalPhotoInBackground(captured);
}
```

Это - код из `MainPage.OnCaptureSuccess`. Шейдеры грузятся из `src/Sample/Resources/Raw/Shaders`.

## Отрисовка поверх кадров

Виртуальные методы `RenderPreviewForProcessing` и `RenderFrameForRecording` подготавливают `SKCanvas`, который затем передаётся в колбэки `ProcessPreview` или `ProcessFrame` - там мы уже рисуем поверх кадров всё что нужно.

Внутри можно пользоваться обычными примитивами SkiaSharp: `SKCanvas.DrawText`, `DrawRect` и прочими. Но для сложной композиции оверлеи удобно собирать с помощью DrawnUI.

На сегодня наш оверлей содержит два видимых модуля:

- эквалайзер в правом верхнем углу
- панель субтитров, вертикально по центру в режиме предпросмотра и внизу экрана при записи

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

Для эквалайзера мы используем тип кеша ImageDoubleBuffered, чтобы не тормозить рендеринг кадра. Новый кеш готовится в фоне, а на холст кадра быстро выводится последний готовый растр.

В `AppCamera.DrawOverlay` мы адаптируем и режим, и масштаб.
`layout.AdaptLayoutToMode(frame.IsPreview)` меняет вертикальное размещение субтитров для режимов предпросмотра и записи. Мы используем `frame.Scale`, чтобы один и тот же лейаут оставался визуально одинаковым и в небольшом превью, и в большом кадре идущем на запись.

>Чтобы узнать точное расположение элемента камеры на SkiaSharp-холсте, можно использовать свойство камеры `SKRect DrawingRect`. Если свойство `Aspect` выставлено не в `Fill`, а в `Fit`, то реальный кадр может рисоваться с чёрными полосами по сторонам. Тогда можно использовать свойство `SKRect DisplayRect`, чтобы получить точную область изображения без лишнего пространства вокруг.

## AI-субтитры для речи

Приложение переводит речь в текст с помощью модели **OpenAI Whisper** и кодирует субтитры в финальное видео в реальном времени.
Сервис лежит в `src/Sample/Services/OpenAi/OpenAiAudioTranscriptionService.cs`.

<img src="https://taublast.github.io/assets/img/captions.jpg" alt="Николай Ковальский" width="350" />

*Автор тестирует субтитры на Android, кадр из итогового видео с debug-информацией.*

В [предыдущей статье](https://habr.com/ru/articles/1009382/) мы подробно разбирали, как получать аудио из `SkiaCamera`. Подключим транскрипцию так:

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

Чтобы включить AI-субтитры в вашей копии приложения, откройте `src/Sample/Secrets.cs` и вставьте ваш OpenAI-ключ:

```csharp
public static string OpenAiKey = "sk-...";
```

Без ключа приложение нормально собирается и запускается, но AI-субтитры будут отключены.

Полученный текст мы пробрасываем в оверлей так:

```csharp
_captionsEngine.CaptionsChanged += spans =>
	MainThread.BeginInvokeOnMainThread(()
        => _previewFrameOverlay.SetCaptions(spans));
```

Субтитры удобно рисовать на холсте с помощью DrawnUI:

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

Субтитрами управляет `RealtimeCaptionsEngine`. Каждый абзац хранится до тех пор, пока либо не придёт более новый, либо не истечёт таймер последнего добавленного абзаца. Когда таймер последнего абзаца истекает, мы [применяем шейдер](https://drawnui.net/articles/shaders.html), чтобы растворить его, выглядит как исчезание сообщений в Телеграм:

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

Полная версия кода в `FrameOverlay.cs` отменяет уже запущенную анимацию перед стартом новой, чтобы переключения не наслаивали эффекты.

## GPS и метаданные

Включить геотегирование можно одним флажком:

```csharp
InjectGpsLocation = true;
```

Можно вызвать `RefreshGpsLocation`, мосле включения камеры, чтобы обновить координаты:

```csharp
if (CameraControl.InjectGpsLocation)
    _ = CameraControl.RefreshGpsLocation();
```

После этого GPS встраивается в метаданные автоматически - в контейнер MP4 для видео и в EXIF для фотографий. Координаты не нужно подставлять вручную.

Для видео можно также в метаданные контейнера поля брендирования:

```csharp
// CameraControl.RecordingSuccess += OnRecordingSuccess;
private async void OnRecordingSuccess(object sender, CapturedVideo capturedVideo)
{
	capturedVideo.Meta.Vendor = "Me";
	capturedVideo.Meta.Software = "My App";
	var publicPath = await CameraControl.MoveVideoToGalleryAsync(capturedVideo, MauiProgram.Album);
}
```

Для фотографий доступен полный набор EXIF: ISO, выдержка, диафрагма, фокусное расстояние, ориентация, GPS и прочее. Модель `Metadata` даёт доступ ко всему перед сохранением:

```csharp
// CameraControl.CaptureSuccess += OnCaptureSuccess;
private async void OnCaptureSuccess(object sender, CapturedImage captured)
{
	captured.Meta.Software = "My App";
	var path = await CameraControl.SaveToGalleryAsync(captured, "MyAppAlbum");
}
```

## Заключение

Если вам нужен полный контроль над записью, использованием данных от камеры для AI/ML, и решение других настандартных задач с использованием камеры на .NET MAUI, то пакет DrawnUi.Maui.Camera и SkiaCamera - очевидный выбор.

Если пакет поможет вам в разработке, - пожалуйста, дайте знать. буду рад увидеть, что работа оказалась полезной другим. PR-ы в репозиторий только приветствуются!

## Ссылки и ресурсы

- [DrawnUi.Maui.Camera](https://github.com/taublast/DrawnUi.Maui.Camera) - репозиторий контрола SkiaCamera с sample app и документацией
- [DrawnUi.Maui.Demo](https://github.com/taublast/DrawnUi.Maui.Demo) - пример использования SkiaCamera для фотографий с XAML/MVVM
- [Building a Real-time Audio Processing App](https://habr.com/ru/articles/1009382/) - более ранняя статья об использовании SkiaCamera для аудио с примером приложения
- [Real-Time Camera Filters](../FiltersCamera/) - более ранняя статья на английском о применении SKSL-шейдеров со SkiaCamera и примером приложения
- [DrawnUI for .NET MAUI](https://github.com/taublast/DrawnUi) - OSS-репозиторий движка рендеринга, на котором построен этот контрол
- [SkiaSharp](https://github.com/mono/SkiaSharp) - базовая 2D-графическая библиотека, благодаря которой всё это стало возможным

---

 *Автор открыт для сотрудничества в отношении создания и ускорения мобильных приложений на .NET MAUI, и создания нестандартных UI элементов.*