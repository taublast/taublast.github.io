---
layout: post
title: "Как использовать Rust внутри приложений на .NET MAUI"
description: "Как использовать Rust вместе с .NET MAUI на Android, iOS, MacCatalyst и Windows с помощью RustMaui"
date: 2026-04-28 08:00:00 +0000
categories: [MAUI, Rust, SkiaSharp]
tags: [dotnetmaui, rust, ffi, p-invoke, skiasharp, interop]
image: /assets/img/rust.jpg
---

<img src="https://taublast.github.io/assets/img/ru/rust.jpg" height="350" />

## Когда важна производительность

Что, если какая-то часть вашего приложения на **.NET MAUI** становится слишком тяжелой? Не все приложение целиком, только та часть, которая, возможно, занимается обработкой данных или изображений, вычислениями и тому подобным, и вы начинаете думать, что с этим теперь делать.

Именно в такой момент идея использовать **Rust** внутри приложения начинает выглядеть очень привлекательно.

По производительности Rust находится в той же лиге, что и C++, но с заметно более дружелюбной моделью безопасности. Возможно, вы уже слышали о командах, которые постепенно переходят на **Rust**, заменяя существующий код. А если вам уже приходилось бороться с лагами от GC или пытаться сделать плавную анимацию, отсутствие сборщика мусора начинает выглядеть особенно заманчиво.

Но можно ли сделать так, чтобы использовать **Rust** внутри приложения на **.NET MAUI** было действительно удобно?

Наш ответ: **да**, и для этого мы воспользуемся .NET-инструментом, сделает максимум за нас и работа будет выглядеть одинаково на **Android, iOS, MacCatalyst и Windows**.

## Подключаем Rust к MAUI

Для этой статьи мы соберем реальный пример со SkiaSharp, где C# и Rust рисуют на одном и том же холсте, чтобы показать, как **MAUI** и **Rust** могут работать с одним и тем же контекстом.

Сначала установим специальный инструмент и сгенерируем с его помощью новое приложение. Тот же инструмент можно применить и к уже существующему приложению, но об этом чуть позже. Начнем с установки [RustMaui](https://github.com/taublast/RustMaui):

```bash
dotnet tool install --global RustMaui
```

Если у вас уже есть готовое приложение MAUI, инструмент может подключить Rust и к нему:

```bash
rustmaui init path/to/MyApp.csproj
```

Если вы уже находитесь в директории приложения и там есть ровно один `.csproj`, сработает и сокращенный вариант:

```bash
rustmaui init .
```

Это добавит Rust crate и пакет генератора, не заменяя существующие файлы приложения.

Но в нашем случае мы создадим новое приложение:

```bash
rustmaui new UseSkiaSharp
```

Будет сгенерировано следующее:

```text
UseSkiaSharp/
├── check-prerequisites.ps1
├── check-prerequisites.sh
├── Prerequisites.md
├── rust/
│   ├── Cargo.toml
│   ├── lib.rs 
├── src/
│   └── UseSkiaSharp/
│       ├── AppShell.xaml
│       ├── MainPage.xaml
│       ├── MainPage.xaml.cs
│       ├── MauiProgram.cs
│       └── UseSkiaSharp.csproj
└── UseSkiaSharp.sln
```

Перед первой сборкой стоит проверить prerequisites. Если что-то не настроено, первая сборка завершится ошибкой довольно рано, и сообщение обычно будет достаточно прямым: не установлены компоненты MAUI, отсутствует `cargo`, не добавлены целевые платформы Rust, отсутствует `cargo-ndk`, на macOS не хватает инструментов Xcode, а на Windows может не оказаться линковщика MSVC.

Как можно заметить, сгенерированное приложение содержит [Prerequisites.md](https://github.com/taublast/RustMaui/blob/master/samples/UseSkiaSharp/Prerequisites.md). Если открыть сгенерированный `.sln`, вы увидите этот файл в `Solution items`. Там же лежат вспомогательные скрипты для проверки окружения, чтобы убедиться, что у вас есть все необходимое для сборки Rust-кода. Скрипты подскажут, чего именно не хватает, и выведут команду для исправления или ссылку на установку.

Когда проверка окружения проходит успешно, можно собирать приложение:

```bash
dotnet build
```

В результате мы получаем чистое приложение **.NET MAUI + Rust**, где Rust crate уже подключен к проекту MAUI и все компилируется вместе. Rust-библиотека будет автоматически собираться и упаковываться вместе с MAUI-проектом на **Android, iOS, MacCatalyst и Windows**.

Вы увидите, что появились новые файлы:

```text
UseSkiaSharp/
├── src/
│   └── UseSkiaSharp/
│       ├── AppShell.xaml
│       ├── MainPage.xaml
│       ├── MainPage.xaml.cs
│       ├── MauiProgram.cs
│       ├── Rust.cs <-- здесь можно переопределять биндинги
│       ├── Rust.Generated.cs <--  биндинги сгенерированы автоматически!
│       └── UseSkiaSharp.csproj
└── UseSkiaSharp.sln
```

При первой сборке генератор создает `Rust.cs`, если файла еще нет, и пересоздает `Rust.Generated.cs` при каждой сборке. При необходимости это имя можно изменить.

## Как добавить Rust-код

Напишем экспорт Rust, например такой:

```rust
#[no_mangle]
pub extern "C" fn compute_me(value: f32) -> f32 {
    value * 2.0
}
```

Генератор автоматически создаст C#-биндинг в соответствии с соглашениями об именовании в .NET:

```csharp
// Rust.Generated.cs — do not edit
[LibraryImport(Lib, EntryPoint = "compute_me")]
[UnmanagedCallConv(CallConvs = new[] { typeof(System.Runtime.CompilerServices.CallConvCdecl) })]
public static partial float ComputeMe(float value);
```

После этого его можно вызывать прямо из .NET:

```csharp
var result = Rust.ComputeMe(3.14f);
```

## Возвращаемся к SkiaSharp

Наш финальный пример намеренно маленький: **C# рисует прямоугольник, Rust рисует круг, и оба рисуют на одном и том же холсте SkiaSharp**.

Сам круг здесь не главное. Главное в том, что через тот же самый мост можно точно так же вызывать Rust для обработки изображений, нативных конвейеров обработки данных, геометрии или любой другой работы, где нужен низкоуровневый контроль.

<img src="https://taublast.github.io/assets/img/useless.jpg" alt="Rust в MAUI на Android" />

Внутри сгенерированного проекта MAUI добавим ссылку на пакет:

```xml
<PackageReference Include="SkiaSharp.Views.Maui.Controls" Version="3.119.0" />
```

Затем включим хостинг SkiaSharp в `MauiProgram.cs`:

```csharp
using SkiaSharp.Views.Maui.Controls.Hosting;

builder
    .UseMauiApp<App>()
    .UseSkiaSharp();
```

На этом этапе приложение по-прежнему собирается, но пока не делает ничего интересного.

Сгенерированная страница-пример начинается с обычной демонстрации простой арифметики. Мы заменим ее на холст SkiaSharp:

```xml
<ContentPage xmlns="http://schemas.microsoft.com/dotnet/2021/maui"
             xmlns:x="http://schemas.microsoft.com/winfx/2009/xaml"
             xmlns:skia="clr-namespace:SkiaSharp.Views.Maui.Controls;assembly=SkiaSharp.Views.Maui.Controls"
             x:Class="UseSkiaSharp.MainPage">

    <Grid RowDefinitions="Auto,*">
        <Label Grid.Row="0"
               Text="C# draws the rectangle. Rust draws the circle."
               HorizontalTextAlignment="Center" />

        <skia:SKCanvasView Grid.Row="1"
                           PaintSurface="OnPaintSurface" />
    </Grid>

</ContentPage>
```

В коде этой страницы рисуем прямоугольник на стороне C#, а затем передаем тот же нативный handle холста в Rust:

```csharp
        //MAUI
        canvas.DrawRect(rect, _rectPaint);

        var cx = rect.MidX;
        var cy = rect.MidY;
        var radius = MathF.Min(rect.Width, rect.Height) * 0.25f;
        
        //RUST
        int rc = Rust.DrawCircle(canvas.Handle, cx, cy, radius, ColorArgb);
```

Мы передаем в Rust тот же самый нативный handle `SKCanvas` и даем Rust возможность вызывать Skia на этом конкретном холсте.

## Добавляем Rust-код для Skia

Сгенерированное приложение начинается только с `rust/lib.rs`. Для этого примера я разделил часть на Rust на две зоны ответственности:

- `lib.rs` содержит экспортируемую поверхностью, которую вызывает C#
- `skia.rs` хранит внутреннюю реализацию Skia и платформенно-зависимую загрузку


После этого Rust-часть выглядит так:

```text
UseSkiaSharp/
├── rust/
│   ├── Cargo.toml
│   ├── lib.rs <-- экспортируемые функции для C#
│   └── skia.rs <-- внутренняя реализация Skia и платформенная логика
```

Такое разделение сохраняет публичный ABI компактным и предсказуемым, а Rust-реализации позволяет дальше развиваться обычным образом.

`Cargo.toml` остается намеренно минимальным:

```toml
[lib]
path = "lib.rs"
```

RustMaui сам выбирает стратегию линковки на платформах Apple во время сборки, так что самому примеру не нужно жестко задавать crate types в `Cargo.toml`. 

Пример должен работать одинаково на Windows, Android, iOS, Mac Catalyst и macOS, но стратегия загрузки нативной части там различается.

На Windows, Android, macOS и Mac Catalyst Rust динамически разрешает `libSkiaSharp` через `libloading`. На iOS, и для сборок под устройство, и для симулятора, вместо этого используется путь со статической линковкой, и те же самые символы `sk_*` разрешаются через обычную схему линковки Apple.

`lib.rs` остается небольшим. Он экспортирует только то, что нужно стороне C#, и передает реальную работу внутреннему модулю:

```rust
use std::ffi::c_void;
use std::os::raw::{c_float, c_uint};
use std::sync::Mutex;

mod skia;

static LAST_ERROR: Mutex<Option<String>> = Mutex::new(None);

#[no_mangle]
pub extern "C" fn draw_circle(
    canvas: *mut c_void,
    cx: c_float,
    cy: c_float,
    radius: c_float,
    color_argb: c_uint,
) -> i32 {
    match skia::draw_circle(canvas, cx, cy, radius, color_argb) {
        Ok(()) => {
            *LAST_ERROR.lock().unwrap() = None;
            0
        }
        Err((code, message)) => {
            *LAST_ERROR.lock().unwrap() = Some(message);
            code
        }
    }
}

#[no_mangle]
pub extern "C" fn last_error_message(buffer: *mut u8, buffer_len: usize) -> usize {
    let guard = LAST_ERROR.lock().unwrap();
    let Some(message) = guard.as_ref() else {
        return 0;
    };

    let bytes = message.as_bytes();
    // Return the full required size even on the size-query pass so C# can allocate once.
    let required_len = bytes.len() + 1;

    if !buffer.is_null() && buffer_len != 0 {
        let copy_len = bytes.len().min(buffer_len.saturating_sub(1));
        unsafe {
            std::ptr::copy_nonoverlapping(bytes.as_ptr(), buffer, copy_len);
            *buffer.add(copy_len) = 0;
        }
    }

    required_len
}
```

Интересная платформенная часть находится в `skia.rs`:

- Windows, Android, macOS и Mac Catalyst используют реализацию на `libloading`, которая во время выполнения разрешает уже загруженную бинарную библиотеку `libSkiaSharp`.
- iOS device и iOS Simulator используют отдельную реализацию с обычными `extern "C"`-объявлениями, так что все iOS targets идут по одному и тому же пути со статической линковкой.

```rust
#[cfg(any(
    not(target_os = "ios"),
    target_abi = "macabi"
))]
mod backend {
    fn lib_candidates() -> &'static [&'static str] {
        #[cfg(target_os = "windows")]
        { &["libSkiaSharp.dll", "SkiaSharp.dll"] }

        #[cfg(target_os = "android")]
        { &["libSkiaSharp.so"] }

        #[cfg(any(
            target_os = "macos",
            all(target_os = "ios", target_abi = "macabi")
        ))]
        { &["libSkiaSharp", "libSkiaSharp.dylib"] }
    }
}

#[cfg(all(target_os = "ios", not(target_abi = "macabi")))]
mod backend {
    // iOS device + simulator path: static-link backend using extern "C" declarations
}
```

Генератор C#-биндингов следует тому же правилу. На iOS RustMaui генерирует `Lib = "__Internal"`; на Mac Catalyst он сохраняет реальное имя нативной библиотеки. Именно поэтому один и тот же пакет без проблем собирается для iPhone, iOS Simulator и Mac Catalyst.

## Генератор кода в работе

Именно здесь нам помогает автоматически установленный пакет `RustMaui.Generators`.

После того как я добавил `draw_circle` и `last_error_message` в `lib.rs`, я снова собрал приложение и не писал никаких привязок вручную.

Сгенерированный файл получился таким:

```csharp
// Rust.Generated.cs — do not edit
[LibraryImport(Lib, EntryPoint = "draw_circle")]
[UnmanagedCallConv(CallConvs = new[] { typeof(System.Runtime.CompilerServices.CallConvCdecl) })]
public static partial int DrawCircle(IntPtr canvas, float cx, float cy, float radius, uint colorArgb);

[LibraryImport(Lib, EntryPoint = "last_error_message")]
[UnmanagedCallConv(CallConvs = new[] { typeof(System.Runtime.CompilerServices.CallConvCdecl) })]
public static partial nuint LastErrorMessage(IntPtr buffer, nuint bufferLen);
```

А `Rust.cs` остался без изменений:

```csharp
public static partial class Rust
{
    // Add manual bindings, helpers, or overrides here.
}
```

Отличный результат.

Экспортируемые Rust-сигнатуры в этом примере используют только те типы, которые генератор уже умеет обрабатывать:

- `*mut c_void` превращается в `IntPtr`
- `*mut u8` превращается в `IntPtr`
- `c_float` превращается в `float`
- `c_uint` превращается в `uint`
- `i32` превращается в `int`
- `usize` превращается в `nuint`

Поэтому никакого ручного переопределения в `Rust.cs` не понадобилось.

Совпадает с тем, куда движется современный interop в .NET: автоматичеки сгенерированные привязкина `[LibraryImport]` считаются предпочтительным направлением для сценариев, совместимых с NativeAOT.

## Зачем нужен `Rust.cs`

`Rust.cs` важен в случаях, когда генератор не может сам безопасно определить контракт marshaling.

Типичные примеры:

- строки вроде `*const c_char`
- более сложные правила владения указателями
- кастомное поведение маршалинга
- сигнатуры, для которых вы хотите вручную написать import

В таких случаях сохраняйте Rust export в `lib.rs`, а затем добавляйте собственное объявление `[LibraryImport]` в `Rust.cs`. Генератор увидит совпадающий `EntryPoint` и не станет генерировать дубликат.

Если для одного экспорта нужна вручную написанная привязки, можно переопределить только ее, остальное будет сгенерированно автоматически. В этом примере вручную привязывать не пришлось: автогенератор отлично справился.

- `Rust.Generated.cs` одноразовый и пересоздается на каждой сборке
- `Rust.cs` принадлежит вам и переживает будущие сборки

Если вам нужно другое имя interop-класса вместо `Rust`, задайте `RustBindingsName` в файле проекта:

```xml
<PropertyGroup>
    <RustBindingsName>MyBindings</RustBindingsName>
</PropertyGroup>
```

Тогда вы получите `MyBindings.cs`, `MyBindings.Generated.cs` и partial-класс `MyBindings`.

## Кроссплатформенный Rust

Главная ценность инструмента [RustMaui](https://github.com/taublast/RustMaui) в том, что после первичной настройки всех требований Rust-код компилируется и пакуется вместе с приложением на любой платформе, под которую мы собираем наше .NET MAUI-приложение.

Пример в этой статье намеренно маленький, но он хорошо показывает, как MAUI и Rust могут совместно работать в одном и том же контексте.

С учетом того, что AI сегодня легко поможет перености часть кода с C# на Rust, а этим точно стоит воспользоваться, показанный инструментарий открывает дверь к практичным сценариям использования:

- обработка изображений и данных
- кодеки, парсеры и нативные конвейеры обработки данных
- симуляции или задачи с тяжелой геометрией
- эксперименты с нативными API, где важен низкоуровневый контроль

Надеюсь, что эта статья и **RustMaui** окажутся полезными для ваших проектов! 

<img src="https://taublast.github.io/assets/img/rustyammy.jpg" height="350" alt="RustMaui" />

## Ссылки и ресурсы

- [UseSkiaSharp sample](https://github.com/taublast/RustMaui/tree/master/samples/UseSkiaSharp) рабочий пример, использованный в этой статье
- [RustMaui](https://github.com/taublast/RustMaui) общий репозиторий для глобального инструмента, пакета генератора и пакета шаблонов
- [Working with Rust Libraries from C# .NET Applications](https://khalidabuhakmeh.com/working-with-rust-libraries-from-csharp-dotnet-applications) с практическим разбором .NET + Rust
- [Building with .NET and Rust: A Tale of Two Ecosystems](https://www.woodruff.dev/building-with-net-and-rust-a-tale-of-two-ecosystems/) со сравнением экосистем на более широком уровне
- [Native Library Interop for .NET MAUI](https://learn.microsoft.com/en-us/dotnet/communitytoolkit/maui/native-library-interop/) руководство
- [Native interoperability best practices](https://learn.microsoft.com/en-us/dotnet/standard/native-interop/best-practices) рекомендации .NET по `LibraryImport`, строкам и правилам владения

---

*Автор открыт для сотрудничества в работе над приложениями и кастомными UI-элементами для .NET MAUI. Если вам нужна помощь разработке приложений "под ключ", нативными привязками, или повышением производительности существующих приложений, - обращайтесь.*