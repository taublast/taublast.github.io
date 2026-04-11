---
layout: post
title: "Создание приложения для аудиообработки в реальном времени и SKSL-шейдерами c помошью .NET MAUI"
date: 2026-03-05 12:00:00 +0000
categories: [MAUI, DrawnUI, Audio, Shaders]
tags: [dotnetmaui, skiasharp, drawnui, audio, sksl, shaders]
description: Нюансы разработки  визуально привлекательного приложения с SKSL-шейдерами для определения музыкальных нот и BPM используя возможности .NET MAUI и DrawnUI SkiaCamera.
image: /assets/img/soltempo_git.jpg
---

# Создание приложения для аудиообработки с привлекательными SKSL-шейдерами

Давайте создадим симпатичное приложение, которое будет рисоваться на холстике как Flutter, но писать мы будем на C#  и максимум отвлечемся на синтаксис шейдеров [SKSL](https://skia.org/docs/user/sksl/) от Гугла. Забудем, все, что мы слышали про .NET MAUI и начнем творить на Skia холсте.

В элемент, читай "контрол", [SkiaCamera](https://github.com/taublast/DrawnUi.Maui.Camera) в составе DrawnUI для .NET MAUI недавно приехали улучшения, которые открывают возможности для обработки видео и аудио в реальном времени. Об обработке видео кадров обязательно я расскажу в следующей статье, пока давайте разберёмся со звуком: здесь нам достаточно будет работы контрола в режиме аудио-мониторинга.

*Если взять две октавы подряд, приложение анимирует шейдер достижения с золотыми лучами, поверх двух других шейдеров, имитирующих стекло. Андроид.*

<iframe src="https://taublast.github.io/assets/vids/pitch.mp4"
        style="width: 100%; max-width: 640px; max-height: 360px;"
        frameborder="0"></iframe>

Специально для этой статьи я создал приложение [с открытым исходным кодом](https://github.com/taublast/SolTempo) на .NET MAUI под iOS, Mac Catalyst, Android и Windows. Небольшая песочница для демонстрации работы мониторинга и обработка аудио в `SkiaCamera`. Тут сразу захотелось добавить визуала: шейдеры с эффектом **жидкого стекла**, анимации переходов и прочее, что хорошо реализуется на **SkiaSharp** в **.NET MAUI**.

Коротко, приложение творит следующее:

- ловит звук с микрофона
- примененяет преобразования (в моём случае это усиление `+5`, и тут может быть что угодно: изменение голоса, эквалайзер, подавление шума и т.п.)
- анализирует аудиосэмплы (определение нот / BPM)
- визуализирует результаты анализа

<img src="https://taublast.github.io/assets/img/sol_screenshots.png" alt="SolTempo" width="800"
style="margin-top: 16px;" />

Чтобы приложение можно было сразу поставить и проверить "как там оно", я залил его под именем `SolTempo` в [AppStore](https://apps.apple.com/app/soltempo/id6759321593) и [GooglePlay](https://play.google.com/store/apps/details?id=com.appomobi.soltempo).

## Что умеет

- Определяет высоту ноты в реальном времени для голоса и инструментов и показывает, насколько вы выше или ниже ближайшего полутона
- Дает выбрать отображение нот: буквы, сольфеджио do..la-si/do..la-ti, кириллица до-ре-ми, цифры..
- Умеет работать полутонами (`C#`, `Eb` и т.д.) и в режиме только натуральных нот
- Считает BPM / темп в диапазоне `40-260`
- Позволяет выбрать звуковое устройство ввода
- Может применять к входящему сигналу дополнительное усиление `+5`
- Показывает визуальные достижения: «Полная октава» и «Идеальная серия», это - конфетти и полноэкранный шейдер

## Один холст

Всё приложение рисуется на одном аппаратно-ускоренном холсте, он же `Canvas`, созданный на базе `SKCanvas` от **SkiaSharp**. Из нативных элементов тут, по сути, только то, что показывается через `DisplayActionSheet`: такие вещи удобно не изобретать под новое приложение, а сохранить знакомое людям платформенное отображение вариантов выбора.

Навигация, модальные окна и попапы тоже живут внутри этого холста. Все это виртуальное, рисованное, никаких нативных вьюшек и хендлеров, все - одна рисуемая сцена. Даёт больше свободы и по визуалу, и по производительности. Элементы, которые не менялись, рисуются из кеша (операции или растер), измененные - отрисовываются заново, холст обновляется только тогда, когда что-то поменялось.

Чтобы наш UI выглядел интересно, будем использовать:

- анимированный шейдер при переключении модулей
- анимированные шейдеры появления и исчезновения попапов
- динамический "backdrop" c шейдером-эффектом жидкого стекла за основной панелью
- такой же фон для нижней панели с кнопками
- постоянно (при приходе нового аудио семпла) рисующийся внизу аудиоэквалайзер
- "простой" рисованный на холсте эффект конфетти для достижения «Полная октава»
- анимированный "вау" шейдер для достижения «Идеальная серия»

Интерфейс опишем кодом, без XAML. Нормально работает с .NET HotReload, [DrawnUI](https://drawnui.net) закрывает нам все потробности размещения на холсте: расположение элементов, жесты, эффекты (в т.ч. шейдеры) и прочее.

Например, стеклянная панель за модулем с нотами выглядит так:

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

Подложка, она же "backdrop", берёт то, что уже нарисовано на фоне, потом визуальный эффект прогоняет это через шейдер. Если нужно, свои эффекты можно писать с нуля или наследоваться от уже готовых. В моём случае `GlassBackdropEffect` наследуется от `SkiaShaderEffect` и добавляет простой набор удобных свойств поверх шейдера `glass.sksl`, который лежит в `Resources\Raw` внутри MAUI-приложения. Чуть ниже покажу это подробнее.

Можно было бы сделать всё и на XAML, но сегодня специально будет только "[code-behind](https://drawnui.net/articles/fluent-extensions.html)", хот-релоад работает на отлично:

<iframe src="https://taublast.github.io/assets/vids/hotreload.mp4"
        style="width: 100%; max-width: 640px; max-height: 360px;"
        frameborder="0"></iframe>

*.NET HotReload в деле: меняем emboss у карточки модуля.*

## SkiaCamera и аудио в реальном времени

`SkiaCamera` умеет пропускать сквозь себя входящие аудио-семплы по одному, и на этой базе можно собрать вполне себе удобный кроссплатформенный пайплайн. Мы получаем звук, при необходимости применяем к нему преобразования, затем анализируем сэмплы для определения нот и BPM, дальше передаём всю информацию в UI-визуализаторы.

### Режим только аудио

В SolTempo я сделал свой подкласс `SkiaCamera`, который отключает видео-функционал и включает аудиомониторинг. В самом приложении он добавлен в дерево UI как скрытый элемент, но в другом проекте такой объект вполне можно держать и внутри ViewModel как сервис:

```csharp
public partial class AudioRecorder : SkiaCamera
{
	public AudioRecorder()
	{
        // флаги разрешений, которые необходимы/запросит при включении контрола
		NeedPermissionsSet = NeedPermissions.Microphone;

		// включить режим АУДИО
		EnableAudioMonitoring = true; //используем
		EnableAudioRecording = true; //просто разрешили себе на будущее

		// отключить режим ВИДЕО
		EnableVideoPreview = false;
		EnableVideoRecording = false;
	}

	public float GainFactor { get; set; } = 5.0f;
	public bool UseGain { get; set; }

    // здесь можно подключить любую обработку
	protected override AudioSample OnAudioSampleAvailable(AudioSample sample)
	{
		if (UseGain && sample.Data != null && sample.Data.Length > 1)
		{
			// Усиление PCM16 аудиоданных
			AmplifyPcm16(sample.Data, GainFactor);
		}

		OnAudioSample?.Invoke(sample);
		return base.OnAudioSampleAvailable(sample);
	}
}
```

Тут мы ничего не пишем в файл, это именно мониторинг и анализ, но тот же механизм `OnAudioSampleAvailable` можно использовать и для записи, измененный семл пойдет в нативный кодировщик аудио в реальном времени.

Обработанный сэмпл пошел в модули:

```csharp
//мы подключили Recorder.OnAudioSample += OnAudioSample;
private void OnAudioSample(AudioSample sample)
{
	// модуль определения нот
	if (_musicNotesWrapper.IsVisible)
		NotesModule.AddSample(sample);

	// наш модуль BPM
	if (_musicBPMDetectorWrapper.IsVisible)
		_musicBPMDetector?.AddSample(sample);

	// графический эквалайзер внизу
	if (_equalizer.IsVisible)
		_equalizer.AddSample(sample);
}
```

Любые технические алгоритмы анализа звука сегодня уже тянутся с AI, мы же сфокусируемся на визуальной части.

## Модули отрисовки

Когда `AddSample` каждого модуля внутренне применил данные как хотел, нам надо нормально все это отрисовать. И тут движок **DrawnUI для .NET MAUI** особенно к месту: он даёт свои хендлеры для `Canvas` (читай "рендереры") заточенные на отрисовки UI, что для приложений, что для игр и предоставляет удобную систему компоновки элементов в стиле MAUI/WPF и обработки жестов.

**SkiaSharp**, которая лежит в основе всего, используется двумя путями:

- **Через элементы DrawnUI** (`SkiaLabel`, `SkiaShape`, контейнеры и layout'ы) для всего, что, по сути, является UI
- **Через прямую отрисовку на холсте `SKCanvas`** для эквалайзера и прочей чисто рисованной графики

### Рисованные контролы

Элемент [DrawnUI](https://drawnui.net) будет рисоваться при каждом кадре, если он сам и его родители не закэшированы  или если кэш был инвалидирован. Зачем вся эта тема с кешем? Вместо того чтобы каждый кадр раз заново считать компоновку, тени, шрифты и всё остальное, можно быстро отрисовать кеш: либо растер `SkImage`, либо набор операций `SkPicture`. Если использовать кеш правильно, DrawnUI работает фактически в retained-режиме.

Кэш сбрасывается либо вручную, либо автоматически при изменении свойств, например `Text` у `SkiaLabel`. Мы будем вручную вызывать `Update()`, когда после обработки звука нужно перерисовать изменившийся эквалайзер. Это важный момент: холст не будет перерисовываться без причины, обновляется только тогда, когда в сцене действительно что-то поменялось.

Итак, вот как, например, у нас будет выглядеть конструктор модуля определения BPM:

```csharp
public AudioMusicBPM()
{
    UseCache = SkiaCacheType.Operations;

    Children = new List<SkiaControl>
    {
        new SkiaLabel
        {
            FontSize = 140,
            //MonoForDigits = "8", <-- это сделает шрифт моноширинным для цифр, цифры будут занимать ширину "8" и текст не будет "прыгать" при смене числа, если он центрированю Это может быть полезно для HUD и т.д. Мы намеренно тут не используем для более живого/небрежного вида, пускай, ширина текста прыгает.
            CharacterSpacing = 5.0,
            Margin = new (2,16),
            MaxLines = 1,
            LineBreakMode = LineBreakMode.CharacterWrap,
            UseCache = SkiaCacheType.Operations, //а вот и он, кеш
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

Я использую тут расширения [fluent extensions](https://drawnui.net/articles/fluent-extensions.html). И, конечно, помним про жесты:

```csharp
        public override ISkiaGestureListener ProcessGestures(SkiaGesturesParameters args, GestureEventProcessingInfo apply)
        {
            if (args.Type == TouchActionResult.Tapped)
            {
                Reset(); //сбросить аудиомодуль для анализа с нуля
                return this; //"кто обработал жест?"
            }
            return base.ProcessGestures(args, apply); //вернёт null или одного из возможных дочерних элементов, если они что-то обрабатали и хотят забрать жест себе
        }
```

### Прямой доступ к холсту

Если нужен полный контроль над рисованием, у любого `SkiaControl` (базовый элемент DrawnUI) можно переопределить основной метод рисования и выйти напрямую на поверхность холста:

```csharp

protected override void Paint(DrawingContext ctx)
    {
        base.Paint(ctx); //фон + дочерние элементы, например наши лейблы, будут нарисованы автоматически внутри

        //тут у нас полный доступ к холсту SkiaSharp для рисования линий эквалайзера
        //  и т.д.,:
        var canvas = ctx.Context.Canvas; //SkCanvas
        float scale = ctx.Scale; //плотность, сколько пикселей в одной точке
        SKRect destination = this.DrawingRect; //наша область на холсте, в пикселях, после measure/arrange

        //пример обычного примитива SkiaSharp:
        canvas.DrawOval(destination.Width/2.0f, destination.Height/2.0f, 15 * scale, 11 * scale, somePaint); //если используем scale, размер будет одинаковым на любом устройстве/платформе
    }

```

## Шейдеры!

Самая интересная часть здесь, конечно, шейдеры. Будем максимально использовать SKSL-шейдеры, предоставленные SkiaSharp v3. Подход с единым холстом тут особенно хорош ибо шейдеры могут затрагивать сразу всю сцену.

До этого я уже обкатывал шейдеры в демо-приложениях [Filters Camera](https://github.com/taublast/ShadersCamera) и [ShadersCarousel](https://github.com/taublast/ShadersCarousel), так что тут мы пойдем по проторенной дорожке.

### Стеклянный фон

Ну и да, на дворе 2026 год, так что пройти мимо эффекта, похожего на **liquid glass** было бы странно. Для нижней панель с кнопками такой эффект подходит идеально:

<iframe src="https://taublast.github.io/assets/vids/resize.mp4"
        style="width: 100%; max-width: 640px; max-height: 360px;"
        frameborder="0"></iframe>

*Динамический стеклянный фон. На десктопе к нему добавляются ещё и эффекты наведения мыши на кнопки.*

Логично использовать тот же эффект и для основных аудиомодулей, может быть с большей каемкой. В итоге у нас появился `GlassBackdropEffect` - небольшой подкласс `SkiaShaderEffect`, можно навесить на любой контрол. Теперь у нас есть набор параметров, вроде радиуса скругления, глубины, рефракции, свечения по краям, тонировки и так далее. Шейдер применяется когда родительский `SkiaBackdrop` перерисовывается.

В качестве основы я взял хороший GLSL-шейдер под лицензией MIT: https://github.com/bergice/liquidglass. Дальше уже довольно сильно переделал под свои задачи, основное в переделках то, что надо было произвольно делать тонкую/толстую панель:

```csharp
public class GlassBackdropEffect : SkiaShaderEffect
{
	public GlassBackdropEffect()
	{
		ShaderSource = @"Shaders\glass.sksl"; //лежит внутри папки `Resources/Raw` MAUI-приложения
	}

// передаем наши параметры в шейдер
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

     var c = Tint;
     _uniformTint[0] = (float)c.Red; _uniformTint[1] = (float)c.Green;
     _uniformTint[2] = (float)c.Blue; _uniformTint[3] = (float)c.Alpha;
     uniforms["iTint"] = _uniformTint;

     return uniforms;
 }
```

### Анимированные всплывающие окна

Ну, раз уж шейдеры появились в проекте, почему бы не использовать этот путь и для анимации попапов? Вместо обычных scale/fade-эффектов будем использовать шейдер на появление и другой на скрытие:

<iframe src="https://taublast.github.io/assets/vids/popups.mp4"
        style="width: 100%; max-width: 640px; max-height: 360px;"
        frameborder="0"></iframe>

Под это я сделаем класс `AnimatedPopup`, от которого наследуются и окно справки, и настройки. Все детали в [исходном коде](https://github.com/taublast/SolTempo/blob/main/src/Maui/Views/Controls/AnimatedPopup.cs).

### Переход при смене модулей

Переключение между модулями тоже анимируем с SKSL. Это однотекстурный шейдер перехода, которым управляет аниматор прогресса. На `0.0` в шейдер подаётся текстура текущего контрола, на `0.5` мы шлем изображение следующего и с ним эффект доходит до `1.0`.  
Мне показалось что делать двухтекстурный шейдер ([как тут](https://github.com/taublast/ShadersCarousel) будет "чересчур", когда пользователь ожидает, что модуль быстро переключится.

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

<iframe src="https://taublast.github.io/assets/vids/bpm.mp4"
        style="width: 100%; max-width: 640px; max-height: 360px;"
        frameborder="0"></iframe>

*Переключение на BPM-модуль для определения темпа.*

### Конфетти

Здесь никакого шейдера, "обычная" отрисовка конфетти на холсте отлично справляется, и всё рисуется базовыми примитивами SkiaSharp. Загляните в [исходный код](https://github.com/taublast/SolTempo/blob/main/src/Maui/Helpers/Confetti.cs), и попробуйте взять полную октаву чтобы их увидеть 😄

### Эффект достижения

Если подряд чисто пройти двойную октаву, приложение включает эффект золотых лучей, который виден на видео в начале статьи. Для «Идеальной серии» запускается эффект `AchievementEffect`, содержащий полноэкранный SKSL-шейдер. Прикрепили эффект, он отыграл, открепили эффект от контрола:

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


## Встроенный редактор шейдеров в реальном времени

Редактировать SKSL обычно приходится в режиме постоянных проб и ошибок. Чтобы не пересобирать приложение после каждой правки, я сделал встроенный редактор шейдеров. Он открывается, когда вы запустили приложение на Windows и нажали Settings. Какой именно шейдер редактируем назначим через переменную `shaderGlass`:

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
	}.Assign(out shaderGlass) //для редактора шейдеров в режиме разработки
}
```

Дальше это используется так:

```csharp
    private void TappedSettings()
    {
        _settingsPopup?.Show();
#if DEBUG && WINDOWS
        OpenShaderEditor(shaderGlass); //откроется редактор в новом окне
#endif
    }
```

То есть SKSL можно править прямо внутри приложения, нажимать `Apply` и сразу смотреть, как меняется стеклянный фон. А при ошибке при компиляции шейдера редактор сразу покажет вам где именно ошибка.  
Похожий подход я уже использовал в [Filters Camera](https://github.com/taublast/ShadersCamera), реально экономит время.

## Еще немного нюансов

### Справка в формате Markdown

Текст справки для окошка Help, было бы неплохо определить в нормальном формате, а не зашивать строками/спанами. Поэтому попап будет читать Markdown-файл зашитый в приложение (`Resources/Raw/Markdown/help.en.md`), оправляь его в свойство `Text` контрола `SkiaRichLabel`. Этот контрол умеет парсить и рендерить markdown, включая ссылки, нам подходит идеально.

### Ограничение FPS на iOS (экономия батареи)

На iOS `Canvas` использует **Apple Metal** для аппаратного рендеринга. Звучит нелохо, но при постянном обновлении любит есть батарею и греть устройство. Здесь у нас не игра, но пока идёт аудиопоток с частотой `48000 Hz` будет обновлять постоянно, поэтому порежем фпс, для такого приложения нам подойдет:

```csharp
#if IOS // экономим батарею
Super.MaxFps = 30;
#endif
```

Мелочь, но для долгой работы приложения разница вполне ощутимая.

### Оценка приложения

В самом конце разработки можно быстро подключить [Plugin.Maui.AppRating](https://github.com/FabriBertani/Plugin.Maui.AppRating), чтобы аккуратно попросить пользователя поставить оценку опубликованному приложению в магазине: только однажды и только если приложение использовали более часа. Подключается "на раз", что отдельное спасибо автору плагина.

## Заключение

У нас получился компактный, но вполне такой живой полигон для анализа аудио в реальном времени, и экспериментов с SKSL. Заодно неплохо показывает расширенный диапазон применения **.NET MAUI**.  Когда у нас есть SkiaSharp и желание применить рисованный подход, приложение уже не обязано выглядеть как типовой набор нативных элементов.

Хватайте [исходный код](https://github.com/taublast/SolTempo), пробуйте встроенный редактор шейдеров на Windows, и посмотрите, что у вас получится собрать на этой базе. Кстати, запустится и на маке.

## Ссылки и ресурсы

* [SolTempo](https://github.com/taublast/SolTempo) — полный исходный код
* [AppStore](https://apps.apple.com/app/soltempo/id6759321593) — установить приложение на iOS
* [GooglePlay](https://play.google.com/store/apps/details?id=com.appomobi.soltempo) — установить приложение на Android
* [DrawnUI for .NET MAUI](https://github.com/taublast/DrawnUi) — движок для рисованного подхода
* [SkiaSharp](https://github.com/mono/SkiaSharp) — базовая библиотека 2D-графики
* [SKSL documentation](https://skia.org/docs/user/sksl/) — справочник по языку шейдеров Skia
* [Plugin.Maui.AppRating](https://github.com/FabriBertani/Plugin.Maui.AppRating) — быстрый и простой способ попросить пользователей оценить приложение

---

 *Автор открыт в отношении сотрудничества для создания и ускорения мобильных приложений на .NET MAUI, и создания нестандартных UI элементов.*
