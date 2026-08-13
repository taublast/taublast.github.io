---
layout: post
title: "Распознавание лиц с потока камеры в .NET MAUI"
description: "Как использовать SkiaCamera для AI/ML локально и с API"
date: 2026-04-20 8:00:00 +0000
categories: [MAUI, DrawnUI, Camera, AI]
tags: [dotnetmaui, skiasharp, camera, mediapipe, facedetection, drawnui, ml, skiacamera]
image: /assets/img/ru/camfaces.jpg
---

## В этой статье

Сегодняшние приложения для мобильных и настольных устройств умеют распознавать на изображениях почти что угодно, - от QR-кодов до количества калорий в еде на на фото. На платформах, которые поддерживает **.NET MAUI**, для этого можно использовать разные варианты, как локальные ML-движки вроде **TensorFlow Lite**, нативные SDK для конкретной платформы, типа **ARKit** на iOS, так и разные Vision API. Далее все зависит уже от реализации в приложении.

И вот, когда речь идет пойдет о распознавании изображений от камеры, наш вариант - пакет `DrawnUi.Maui.Camera`. В [предыдущей статье](../VideoRecording/) я показывал, как использовать `SkiaCamera` для анализа аудио с AI в реальном времени, а сегодня займемся видео: разберем на примере **распознавания лиц**.

[Приложение-пример](https://github.com/taublast/DetectFaces), которое идет вместе с этой статьей, использует локальное распознавание лицевых точек с помощью **MediaPipe Tasks**. Я выбрал этот вариант ради максимально единообразного поведения на всех платформах: на **iOS, Android и Windows**.

А также наше приложение рисует оверлеи и приклеивает маски к движущимся лицам.

<iframe src="https://taublast.github.io/assets/vids/masks.mp4" width="100%" height="547" frameborder="0"></iframe>

Важно: сегодня наша цель - показать **как использовать живые видеокадры из `SkiaCamera` для AI/ML локально и через API** в целом, не уходя глубоко в детали конкретного приложения.

## Настройка

О том, как установить и инициализировать `SkiaCamera`, я писал в [предыдущей статье](../VideoRecording/). В данном примере мы используем XAML и размещаем унаследованный элемент внутри обычного лейаута .NET MAUI.

Для задач AI/ML нам нужно заставить элемент работать в режиме обработки поступающего видео-потока:

```csharp
UseRealtimeVideoProcessing = true;
```

## Точка подключения

Когда `SkiaCamera` показывает превью, кадры, которые вы видите на экране, находятся в GPU-памяти. Чтобы использовать их асинхронно для своих целей нам нужно вытащить кадр нужного размера в обычную память. Ключевой виртуальный метод: `OnRawFrameAvailable(RawCameraFrame frame)`.

Приходящая структура `RawCameraFrame` содержит `SKImage`, живущий в GPU, а так же сопутствующие метаданные.
Обычно для распознавания нам нужно уменьшить изображение, правильно его повернуть и в некоторых случаях еще чуток кропнуть, чтобы убрать лишние поля, которые не релевантны для распознавания. И все инструменты для этого в пакете у нас есть.

## Для локальной ML модели

Структура `RawCameraFrame` предоставляет метод `TryGetRgba(width, height, buffer, orientation, cropRatio)`, который заполняет заранее выделенный вами `byte[]` RGBA-пикселями в том финальном размере, который нужен вашей модели. 

Если, когда вы укажете новый размер, пропорции будут отличаться от исходных, - после уменьшения изображение сохранит свои пропорции (аспект), заполнив размеры с выравниванием по центру.

В приложении-примере используется `cropRatio` по умолчанию, то есть `1` без дополнительного зума (читай, обрезки полей), и `orientation` по умолчанию `OutputOrientation.Display` - в данном приложении нам не было важно, чтобы картинка была строго "головой вверх"; нам было важно получить ровно то, что пользователь видит на экране, даже если устройство повернуто в ландшафт.

Если для вашей модели важна ориентация "головой вверх", то можно использовать `OutputOrientation.Portrait`. И, возможно, вам еще захочется подрезать кадр, например, убрать края, если нужный объект почти наверняка находится ближе к центру. Для этого можно уменьшить `cropRatio`. Например: `0.9` будет означать, что вы обрежете пропорцию `0.1` по краям кадра.

В нашем примере метод вызывается вообще с дефолтными значения, без явной передачи `orientation, cropRatio)`:

```csharp
	if (!frame.TryGetRgba(targetWidth, targetHeight, _mlFrameBuffers[writeBufferIndex]))
		return;
```

Даже для локального модели лучше всего будет пропускать кадры из видео-потока, пока детектор еще занят. Это касается не только лиц, но и QR-сканирования, OCR, разпознавания объектов, в общем любого сценария, где модель работает нон-стоп. Лучше пропустить часть кадров, чем превью камеры начнет лагать.

Вот пример для абстрактного ML-сценария: не блокируем поток камеры, с пропуском кадров, пока предыдущее распознавание еще идет в другом потоке:

```csharp
private readonly byte[] _rgbaBuffer = new byte[targetWidth * targetHeight * 4];
private readonly SemaphoreSlim _detectorBusy = new(1, 1);

protected override void OnRawFrameAvailable(RawCameraFrame frame)
{
	if (!_detectorBusy.Wait(0))
		return;

	if (!frame.TryGetRgba(targetWidth, targetHeight, _rgbaBuffer, OutputOrientation.Portrait, 0.8f))
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

Следующий пример более оптимизирован: вместо `ToArray()` используется переиспользуемый пул буферов, а работа уходит идет в параллельном потоке, которым управляет ваш детектор, без лишнего оборачивания в `Task.Run`:

```csharp
private readonly byte[][] _mlBuffers =
[
	new byte[targetWidth * targetHeight * 4],
	new byte[targetWidth * targetHeight * 4]
];
private const float MlCropRatio = 1f;
private readonly object _detectionSync = new();
private int _activeBufferIndex = -1;
private DetectionWorkItem? _queuedDetectionWorkItem;

protected override void OnRawFrameAvailable(RawCameraFrame frame)
{
	DetectionWorkItem? workItemToSubmit = null;

	lock (_detectionSync)
	{
		int writeBufferIndex = _activeBufferIndex == 0 ? 1 : 0;

		if (!frame.TryGetRgba(targetWidth, targetHeight, _mlBuffers[writeBufferIndex], OutputOrientation.Portrait, MlCropRatio))
			return;

		var workItem = new DetectionWorkItem(
			writeBufferIndex,
			targetWidth,
			targetHeight,
			0);

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

Здесь фоновый поток принадлежит самому детектору. `OnRawFrameAvailable(...)` только подготавливает кадр, решает, надо ли его пропустить или поставить в очередь, и затем передает дальше. В коллбэке завершения позже освобождается активный буфер и, если нужно, отправляется самый свежий отложенный кадр. Поскольку в этом примере используется `OutputOrientation.Display`, буфер детектора уже выровнен относительно живого превью, и потом не нужно отдельно компенсировать поворот в координатах детектора.

## Для AI API

В приложении используется локальный ML движок, но та же точка подключения подойдет и в случае, если вы хотите работать через API.

Обычно, по соображениям производительности не стоит пытаться отправлять каждый возможный кадр превью. Например, можно разрешать не более одной отправки раз в 300 мс и при этом не слать новый кадр, пока не завершился предыдущий запрос.

Для публичных LLM vision API обычно отправляют `JPEG` или `PNG`. Параметр `cropRatio` доступен и здесь:

```csharp
private const int RemoteUploadIntervalMs = 300;
private long _lastUploadStartedAtMs;
private readonly SemaphoreSlim _uploadGate = new(1, 1);

protected override void OnRawFrameAvailable(RawCameraFrame frame)
{
	if (!_uploadGate.Wait(0))
		return;

	long nowMs = Environment.TickCount64;
	if (nowMs - _lastUploadStartedAtMs < RemoteUploadIntervalMs)
	{
		_uploadGate.Release();
		return;
	}

	if (!frame.TryGetJpeg(targetWidth, targetHeight, out var payload, 100, OutputOrientation.Portrait, 1f))
	{
		_uploadGate.Release();
		return;
	}

	_lastUploadStartedAtMs = nowMs;

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

Здесь аккуратнее всего работает `SemaphoreSlim.Wait(0)`: он не блокирует коллбэк камеры, но при этом гарантирует, что одновременно в полете будет только одна отправка. Уже далее можно спокойно проверить минимальную паузу в 300 мс и обновить `_lastUploadStartedAtMs`. Если сетевой вызов занимает дольше 300 мс, то новые кадры будут просто пропускаться.

`TryGetJpeg(...)` и `TryGetPng(...)` возвращают изображение в том размере и с той ориентацией, которые вы запросили.

Если ваш ендпойнт принимает сырые данные `RGBA8888`, можно по-прежнему использовать `TryGetRgbaBytes(...)`.

## Отладка

Если нужно проверить, что вы реально отправляете в AI/ML, можно сохранить один кадр изображения в галерею устройства и посмотреть глазами. Простой способ убедиться, что с ориентацией, обрезкой все действительно так, как вы ожидаете. Не забудьте дать приложению доступ к галерее, см. [README](https://github.com/DrawnUi/DrawnUi.Net.Maui.Camera) `SkiaCamera`, там всё описано.

Если приложение уже использует `TryGetJpeg(...)`, можно сохранить ровно тот же самый `JPEG`:

```csharp
private bool _saveNextDebugFrame; //установим в true когда надо сохранить текущий кадр в галерею

protected override void OnRawFrameAvailable(RawCameraFrame frame)
{
	if (_saveNextDebugFrame &&
		frame.TryGetJpeg(targetWidth, targetHeight, out var payload, 100, OutputOrientation.Portrait, 1f))
	{
		_saveNextDebugFrame = false;

		_ = Task.Run(async () =>
		{
			using var stream = new MemoryStream(payload);
			await NativeControl.SaveJpgStreamToGallery(
				stream,
				$"ml_debug_{DateTime.Now:yyyyMMdd_HHmmss}.jpg",
				new Metadata(),
				"DebugAlbum");
		});
	}

	// ...
}
```

Если же приложение использует `TryGetRgbaBytes(...)`, то нужно закодировать полученный RGBA-буфер в `JPEG` и уже потом сохранить в галерею:

```csharp
private bool _saveNextDebugFrame;

protected override void OnRawFrameAvailable(RawCameraFrame frame)
{
	if (_saveNextDebugFrame &&
		frame.TryGetRgbaBytes(targetWidth, targetHeight, out var rgbaBytes, OutputOrientation.Portrait, 1f))
	{
		_saveNextDebugFrame = false;

		_ = Task.Run(async () =>
		{
			var imageInfo = new SKImageInfo(
				targetWidth,
				targetHeight,
				SKColorType.Rgba8888,
				SKAlphaType.Unpremul);

			using var image = SKImage.FromPixelCopy(imageInfo, rgbaBytes, imageInfo.RowBytes);
			using var data = image.Encode(SKEncodedImageFormat.Jpeg, 100);
			using var stream = data.AsStream();

			await NativeControl.SaveJpgStreamToGallery(
				stream,
				$"ml_debug_rgba_{DateTime.Now:yyyyMMdd_HHmmss}.jpg",
				new Metadata(),
				"DebugAlbum");
		});
	}

	// ...
}
```

Чем меньше размер, который вы запрашиваете, тем быстрее пройдет операция `GPU кадр -> CPU миниатюра`.

## Приложение-пример

Теперь, когда нам понятно, как получать изображения для AI/ML, читать исходники приложения будет проще. Я добавил и дополнительную документацию (на английском): [Implementation.md](https://github.com/taublast/DetectFaces/blob/main/src/Implementation.md), где разобрана архитектура, и [Includes.md](https://github.com/taublast/DetectFaces/blob/main/src/Includes.md), где объясняется, как ML-модели зашиваются внутри ресурсов приложения для каждой платформы. Ибо всю нашу схему легко адаптировать и под другие `MediaPipe Tasks`: просто меняете модель и парсите другой результат. О том какие еще модели можно подключить, - чуть ниже.

<img src="https://taublast.github.io/assets/img/mask.jpg" alt="Маска, наложенная на обнаруженные лицевые точки" height="350" />

Чтобы можно было рисовать маски-картинки, например маску Человека-паука или Смешную шляпу, мы используем конфигурации, которые задают позиционирование относительно найденного лица:

```csharp
					config = ModePicker.SelectedIndex switch
					{
						3 => new MaskConfiguration
						{
							Filename = "hat_cake.png",
							Position = MaskPosition.Top,
							WidthMultiplier = 1.6f,
							YOffsetRatio = 0.05f
						},
						_ => new MaskConfiguration
						{
							Filename = "mask_spiderman.png",
							Position = MaskPosition.Inside,
							WidthMultiplier = 1.25f,
							YOffsetRatio = -0.2f
						}
					};

					await CameraControl.SetupMaskAsync(config);
```

Если захотите сделать свою маску, можно просто добавить новые конфиги поверх уже существующих.

Чтобы рисовать с максимальным фпс, мы держим текущий растр маски в текстуре на GPU:

```csharp
   //грузим из ресурсов
   using var stream = await FileSystem.OpenAppPackageFileAsync(config.Filename);
   using var managed = new MemoryStream();
   await stream.CopyToAsync(managed);
   managed.Position = 0;

   MaskBitmap = SKBitmap.Decode(managed);
   
   //выполняем в GPU потоке: сохраняем в GPU текстуру
   SafeAction(() => //выполняется в конце отрисовки холста с помощью SkiaSharp
   {
	   using var gpu = this.CreateSurface(MaskBitmap.Width, MaskBitmap.Height, isGpu: true);
	   gpu.Canvas.Clear(SKColors.Transparent);
	   gpu.Canvas.DrawBitmap(MaskBitmap, 0, 0);
	   gpu.Canvas.Flush();
	   MaskImage = gpu.Snapshot();
   });
```

После этого мы можем рисовать `MaskImage` прямо в коллбэке `ProcessFrame` у `SkiaCamera`, с правильной проекцией поворота и позиции.

Тот же код рисования оверлея, который мы используем в `ProcessFrame`, работает у нас и при сохранении снятых фотографий. Фото может быть очень большим, например `4000x3000`, и если рисовать найденные landmark-точки или маски со толщиной `stroke`, рассчитанной для маленького превью, примитивы SkiaSharp на таком размере будут почти не видны. Мы решаем это масштабированием толщины линии от безопасной базы в 300 пикселей:

```csharp
var density = Math.Min(frame.Width, frame.Height) / 300f; 
_paintDetectionDotsStroke.StrokeWidth = Math.Max(2f, 2f * density); 
//рисуем лендмарки - лицевые точки
frame.Canvas.DrawPoints(SKPointMode.Points, pts, _paintDetectionDotsStroke);
```

Так маски и точки визуально сохраняют одинаковый масштаб и в живом превью, и на итоговой фотографии.

Чтобы перемещения маски в кадре при движении головы выглядело плавнее, мы используем One Euro фильтр. Он работает отдельно для каждой landmark-точки, по X и Y, поэтому на неподвижном лице хорошо убирает дрожание, а на движущемся уменьшает шаги перемещения. Дополнительный, шаг обработки `prediction step` (предсказание) экстраполирует положение по двум последним распознаваниям и помогает компенсировать задержку детектора, когда голова двигается быстро.

### Что еще можно распознавать

Архитектура - `MediaPipeTasksVision` на мобильных платформах и `MediaPipe.Net` TFLite graphs на Windows - так же переносится и на другие задачи: достаточно заменить файл модели:

- **Hand landmarks** (`hand_landmarker.task`) - 21 3D-точка суставов на каждую руку, отслеживание жестов
- **Pose landmarks** (`pose_landmarker.task`) - 33 суставные точки тела, отслеживание движений (фитнес, 3D..)
- **Object detection** (`efficientdet.task`) - определение объектов
- **Image segmentation** (`image_segmenter.task`) - попиксельное разделение фон/бэкграунд (тот же механизм лежит в основе размытия фона в Zoom)
- **Image classification** - классификация всего изображения

В приложении-примере мы уже решили множество сложностей реализации и смена модели в основном сводется к разбору другого формата результата.

### Используемые пакеты

* Windows: `Mediapipe.Net` и `Mediapipe.Net.Runtime.CPU`.
* iOS: `MediaPipeTasksVision.iOS` из проекта [MediaPipeTasks](https://github.com/v-hogood/MediaPipeTasks).
* Android: `AppoMobi.Preview.MediaPipeTasksVision.Android`, мой форк `MediaPipeTasksVision.Android` [с дополнительными методами](https://github.com/taublast/MediaPipeTasks/tree/bulkpts) для пакетного чтения landmark-точек, что уменьшает время обработки кадра примерно в 3 раза. PR уже отправлен в основной репозиторий, так что позже, возможно, получится вернуться к оригинальному NuGet-пакету из [MediaPipeTasks](https://github.com/v-hogood/MediaPipeTasks).

## Заключение

Отправлять кадры из живого превью камеры в локальную ML-модель или на API **в .NET MAUI** вполне реально и достаточно комфортно. Показатели производительности в строке состояния в приложении-примере помогут вам в настройке.

Надеюсь, что статья окажется для вас полезной. Если она поможет вам создать что-то интересное, пожалуйста, напишите. Вопросы тоже можно смело оставлять в комментариях!

## Ссылки и ресурсы

- [DetectFaces](https://github.com/taublast/DetectFaces) - приложение-пример, исходный код из этой статьи
- [DrawnUi.Maui.Camera](https://github.com/DrawnUi/DrawnUi.Net.Maui.Camera) - элемент `SkiaCamera`
- [AI Captions and Live Video Processing in .NET MAUI](../VideoRecording/) - предыдущая статья этой серии
- [MediaPipe Tasks Vision - Android](https://ai.google.dev/edge/mediapipe/solutions/vision/face_landmarker/android) - официальная документация MediaPipe для Android
- [MediaPipe Tasks Vision - iOS](https://ai.google.dev/edge/mediapipe/solutions/vision/face_landmarker/ios) - официальная документация MediaPipe для iOS
- [One Euro Filter](https://gery.casiez.net/1euro/) - алгоритм адаптивного сглаживания, который используется для стабилизации маски
- [DrawnUI for .NET MAUI](https://github.com/DrawnUi/DrawnUi.Net) - движок, который рендерит нашу SkiaCamera
- [SkiaSharp](https://github.com/mono/SkiaSharp) - 2D-графическая библиотека, в основе всего этого дела

---

 *Автор открыт для сотрудничества в создании мобильных приложений на .NET MAUI, и кастомных UI элементов.*