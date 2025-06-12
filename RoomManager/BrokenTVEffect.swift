import SwiftUI
import MetalKit
import Metal
import simd
import Combine

// Импортируем структуру RoomViewModel, если она находится в другом файле
// Если модель находится в основном модуле приложения, то просто декларируем протокол

// Определение для TranslationProvider
protocol TranslationProvider {
    func getTranslation(for key: String) -> String
}

// Расширяем, чтобы RoomViewModel мог быть использован как TranslationProvider
extension RoomViewModel: TranslationProvider {}

// MARK: - Модификатор для TVEffectSettingsView
extension TVEffectSettingsView {
    // Инициализатор, который принимает любой объект, способный предоставлять переводы
    init(translationProvider: TranslationProvider) {
        self.viewModel = translationProvider
    }
    
    // Явный инициализатор для RoomViewModel
    init(viewModel: RoomViewModel) {
        self.viewModel = viewModel
    }
}

// MARK: - Структуры данных для эффекта сломанного ТВ
struct TVNoiseUniforms {
    var time: Float
    var viewportSize: SIMD2<Float>
    var noiseIntensity: Float
    var scanlineIntensity: Float
    var glitchIntensity: Float
    var colorDistortion: Float
}

// MARK: - Класс настроек эффекта

class TVEffectSettings: ObservableObject {
    // Флаг для предотвращения рекурсивных вызовов
    private var isUpdatingRefreshRate = false
    
    // Основные настройки
    @Published var isEnabled = true
    
    @Published var refreshRate: Double = 120 {
        didSet {
            // Предотвращаем рекурсивные вызовы
            if isUpdatingRefreshRate { return }
            
            // Валидируем диапазон значений
            let clampedValue = max(30, min(120, refreshRate))
            if abs(refreshRate - clampedValue) > 0.01 {
            isUpdatingRefreshRate = true
            DispatchQueue.main.async { [weak self] in
                    self?.refreshRate = clampedValue
                    self?.isUpdatingRefreshRate = false
                }
            }
        }
    }
    
    // Настройки шума
    @Published var noiseSize: Double = 3.0 // Увеличенный размер точек по умолчанию
    @Published var particleSpeed: Double = 1.0 // Новая настройка скорости движения
    @Published var useScanLines = true
    @Published var scanLineDarkness: Double = 0.85
    @Published var isColoredNoise = false 
    @Published var isHighContrast = true
    
    // Настройки дополнительных эффектов
    @Published var useGlitches = false
    @Published var glitchIntensity: Double = 0.2
    @Published var useBlinking = false
    @Published var blinkingIntensity: Double = 0.1
    
    // Пресеты
    func applyOriginalPreset() {
        isEnabled = true
        refreshRate = 120
        noiseSize = 3.0 // Увеличенный размер для лучшей видимости
        particleSpeed = 1.0
        useScanLines = true
        scanLineDarkness = 0.85
        isColoredNoise = false
        isHighContrast = true
        useGlitches = false
        useBlinking = false
    }
    
    func applyRetroTVPreset() {
        isEnabled = true
        refreshRate = 60
        noiseSize = 4.0 // Более крупные точки для ретро-эффекта
        particleSpeed = 0.7 // Медленнее для эффекта старого ТВ
        useScanLines = true
        scanLineDarkness = 0.7
        isColoredNoise = false
        isHighContrast = false
        useGlitches = true
        glitchIntensity = 0.15
        useBlinking = true
        blinkingIntensity = 0.05
    }
    
    func applyColorfulGlitchPreset() {
        isEnabled = true
        refreshRate = 120 // Оптимизировано для 120Hz
        noiseSize = 2.5 // Более мелкие точки для цветного эффекта
        particleSpeed = 1.5 // Быстрее для динамичного эффекта
        useScanLines = true
        scanLineDarkness = 0.6
        isColoredNoise = true
        isHighContrast = true
        useGlitches = true
        glitchIntensity = 0.4
        useBlinking = true
        blinkingIntensity = 0.2
    }
}

// Расширение для TVEffectSettings для хеширования и отслеживания изменений
extension TVEffectSettings: Hashable {
    static func == (lhs: TVEffectSettings, rhs: TVEffectSettings) -> Bool {
        lhs.hashValue == rhs.hashValue
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(isEnabled)
        hasher.combine(refreshRate)
        hasher.combine(noiseSize)
        hasher.combine(particleSpeed) // Добавляем новую настройку в хеш
        hasher.combine(useScanLines)
        hasher.combine(scanLineDarkness)
        hasher.combine(isColoredNoise)
        hasher.combine(isHighContrast)
        hasher.combine(useGlitches)
        hasher.combine(glitchIntensity)
        hasher.combine(useBlinking)
        hasher.combine(blinkingIntensity)
    }
}

// MARK: - Metal View SwiftUI обертка
struct BrokenTVEffectView: UIViewRepresentable {
    var noiseIntensity: Float = 0.8
    var scanlineIntensity: Float = 0.5
    var glitchIntensity: Float = 0.6
    var colorDistortion: Float = 0.4
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 120  // Установка 120Hz для максимальной частоты мерцания
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0.7)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = true  // Изменено на true для повышения производительности
        mtkView.layer.isOpaque = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.presentsWithTransaction = false // Отключаем для повышения производительности
        
        // Настройка устройства Metal
        if let device = MTLCreateSystemDefaultDevice() {
            mtkView.device = device
            // Инициализация рендера в координаторе
            context.coordinator.setupRenderer(device: device, view: mtkView)
        } else {
            print("Metal не поддерживается на этом устройстве, пропуск инициализации BrokenTVEffectView")
            return mtkView
        }
        
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.noiseIntensity = noiseIntensity
        context.coordinator.scanlineIntensity = scanlineIntensity
        context.coordinator.glitchIntensity = glitchIntensity
        context.coordinator.colorDistortion = colorDistortion
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            noiseIntensity: noiseIntensity,
            scanlineIntensity: scanlineIntensity,
            glitchIntensity: glitchIntensity,
            colorDistortion: colorDistortion
        )
    }
    
    // MARK: - Координатор/Delegate для MTKView
    class Coordinator: NSObject, MTKViewDelegate {
        var noiseIntensity: Float
        var scanlineIntensity: Float
        var glitchIntensity: Float
        var colorDistortion: Float
        
        private var device: MTLDevice?
        private var commandQueue: MTLCommandQueue?
        private var renderPipelineState: MTLRenderPipelineState?
        private var viewportSize = SIMD2<Float>(0, 0)
        private var uniformBuffer: MTLBuffer?
        private var uniforms = TVNoiseUniforms(
            time: 0,
            viewportSize: SIMD2<Float>(0, 0),
            noiseIntensity: 0.8,
            scanlineIntensity: 0.5,
            glitchIntensity: 0.6, 
            colorDistortion: 0.4
        )
        private var startTime: TimeInterval = 0
        
        init(noiseIntensity: Float, scanlineIntensity: Float, glitchIntensity: Float, colorDistortion: Float) {
            self.noiseIntensity = noiseIntensity
            self.scanlineIntensity = scanlineIntensity
            self.glitchIntensity = glitchIntensity
            self.colorDistortion = colorDistortion
            self.startTime = CACurrentMediaTime()
            super.init()
        }
        
        func setupRenderer(device: MTLDevice, view: MTKView) {
            self.device = device
            commandQueue = device.makeCommandQueue()
            
            // Создание uniform буфера с оптимизацией
            uniformBuffer = device.makeBuffer(
                length: MemoryLayout<TVNoiseUniforms>.size,
                options: [.storageModeShared]
            )
            
            // Шейдерный код - оптимизированная версия
            let shaderCode = """
            #include <metal_stdlib>
            using namespace metal;
            
            struct TVNoiseUniforms {
                float time;
                float2 viewportSize;
                float noiseIntensity;
                float scanlineIntensity;
                float glitchIntensity;
                float colorDistortion;
            };
            
            struct VertexOut {
                float4 position [[position]];
                float2 texCoord;
            };
            
            // Оптимизированная функция для псевдослучайных чисел в шейдере
            float random(float2 st) {
                return fract(sin(dot(st.xy, float2(12.9898, 78.233))) * 43758.5453123);
            }
            
            // Упрощенная функция шума для повышения производительности
            float noise(float2 st) {
                float2 i = floor(st);
                float2 f = fract(st);
                
                // Используем более простую интерполяцию для повышения производительности
                float a = random(i);
                float b = random(i + float2(1.0, 0.0));
                float c = random(i + float2(0.0, 1.0));
                float d = random(i + float2(1.0, 1.0));
                
                // Линейная интерполяция вместо кубической для оптимизации
                float2 u = f;
                return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
            }
            
            // Вершинный шейдер - оптимизированный
            vertex VertexOut tvNoiseVertex(uint vertexID [[vertex_id]]) {
                // Константный массив для квада - оптимизация
                float2 vertices[4] = {
                    float2(-1.0, -1.0),
                    float2(1.0, -1.0),
                    float2(-1.0, 1.0),
                    float2(1.0, 1.0)
                };
                
                float2 texCoords[4] = {
                    float2(0.0, 1.0),
                    float2(1.0, 1.0),
                    float2(0.0, 0.0),
                    float2(1.0, 0.0)
                };
                
                VertexOut out;
                out.position = float4(vertices[vertexID], 0.0, 1.0);
                out.texCoord = texCoords[vertexID];
                
                return out;
            }
            
            // Фрагментный шейдер для эффекта сломанного ТВ - оптимизированный
            fragment float4 tvNoiseFragment(VertexOut in [[stage_in]],
                                         constant TVNoiseUniforms& uniforms [[buffer(0)]]) {
                float2 uv = in.texCoord;
                float time = uniforms.time;
                
                // 1. Упрощенный шум "белого снега" - меньше вычислений
                float noise_value = noise(float2(uv.x * 80.0, uv.y * 80.0 + time * 40.0)); 
                float fine_noise = noise(float2(uv.x * 200.0, uv.y * 200.0 - time * 80.0));
                float noise_final = (noise_value * 0.7 + fine_noise * 0.3) * uniforms.noiseIntensity;
                
                // 2. Оптимизированные горизонтальные линии развертки
                float scanline = sin(uv.y * uniforms.viewportSize.y * 0.8 - time * 20.0) * 0.5 + 0.5;
                scanline = scanline * uniforms.scanlineIntensity; // Убираем pow для оптимизации
                
                // 3. Упрощенные глитч эффекты
                float glitch_threshold = 0.85 - uniforms.glitchIntensity * 0.2;
                float glitch_intensity = uniforms.glitchIntensity;
                
                // Более эффективное определение глитча
                float line_noise = step(glitch_threshold, noise(float2(floor(uv.y * 15.0) * 0.1, time * 0.5)));
                float line_shift = (random(float2(floor(uv.y * 8.0), time * 0.5)) * 2.0 - 1.0) * 0.05 * line_noise * glitch_intensity;
                
                // Применяем смещение по горизонтали
                uv.x = fract(uv.x + line_shift);
                
                // 4. Оптимизированное искажение цвета
                float color_shift = uniforms.colorDistortion * 0.02;
                float r = noise(float2(uv.x + color_shift, uv.y + time * 0.05));
                float g = noise(float2(uv.x, uv.y - time * 0.03));
                float b = noise(float2(uv.x - color_shift, uv.y + time * 0.04));
                
                // Упрощенные случайные цветные полосы
                float color_bands = step(0.7, noise(float2(floor(uv.y * 4.0) * 0.2, time * 0.3)));
                r += color_bands * 0.15 * uniforms.colorDistortion;
                g -= color_bands * 0.08 * uniforms.colorDistortion;
                b += color_bands * 0.1 * uniforms.colorDistortion;
                
                // 5. Упрощенное мерцание по времени
                float flicker = 1.0 - (random(float2(time * 0.005, time * 0.005)) * 0.15 * uniforms.glitchIntensity);
                
                // 6. Упрощенные временные пропадания сигнала
                float signal_dropout = step(0.995 - uniforms.glitchIntensity * 0.05, random(float2(floor(time * 4.0), 0.0)));
                float dropout_intensity = 1.0 - (signal_dropout * 0.4);
                
                // Сборка всех эффектов вместе - оптимизировано
                float3 color = float3(r, g, b) * 0.7 + noise_final;
                color = mix(color, float3(noise_final), scanline * 0.4);
                color *= flicker * dropout_intensity;
                
                // Упрощенный эффект виньетирования
                float2 center = float2(0.5, 0.5);
                float dist = length(uv - center);
                float vignette = 1.0 - dist * 1.5; // Упрощенная версия smoothstep
                vignette = max(0.0, min(1.0, vignette));
                color *= vignette;
                
                return float4(color, max(noise_final * 0.4, 0.25)); // Оптимизированная непрозрачность
            }
            """
            
            // Создаем шейдерную библиотеку напрямую из кода
            var dynamicLibrary: MTLLibrary
            do {
                let options = MTLCompileOptions()
                options.languageVersion = .version2_1
                
                // Используем mathMode вместо fastMathEnabled в iOS 18.0+
                if #available(iOS 18.0, *) {
                    options.mathMode = .fast
                } else {
                    #if !targetEnvironment(simulator)
                options.fastMathEnabled = true
                #endif
                }
                
                dynamicLibrary = try device.makeLibrary(source: shaderCode, options: options)
            } catch {
                print("Ошибка создания библиотеки шейдеров: \(error.localizedDescription)")
                
                // Создаем простую fallback-библиотеку с базовыми шейдерами
                let fallbackCode = """
                #include <metal_stdlib>
                using namespace metal;
                
                struct VertexOut {
                    float4 position [[position]];
                    float2 texCoord;
                };
                
                vertex VertexOut tvNoiseVertex(uint vertexID [[vertex_id]]) {
                    float2 vertices[4] = {
                        float2(-1.0, -1.0), float2(1.0, -1.0),
                        float2(-1.0, 1.0), float2(1.0, 1.0)
                    };
                    float2 texCoords[4] = {
                        float2(0.0, 1.0), float2(1.0, 1.0),
                        float2(0.0, 0.0), float2(1.0, 0.0)
                    };
                    
                    VertexOut out;
                    out.position = float4(vertices[vertexID], 0.0, 1.0);
                    out.texCoord = texCoords[vertexID];
                    return out;
                }
                
                fragment float4 tvNoiseFragment(VertexOut in [[stage_in]]) {
                    return float4(0.5, 0.5, 0.5, 0.5);
                }
                """
                
                do {
                    let options = MTLCompileOptions()
                    #if os(iOS) && compiler(>=5.9)
                    if #available(iOS 18.0, *) {
                        options.mathMode = .fast
                    } else {
                        options.fastMathEnabled = true
                    }
                    #else
                    options.fastMathEnabled = true
                    #endif
                    dynamicLibrary = try device.makeLibrary(source: fallbackCode, options: options)
                } catch {
                    print("Не удалось создать fallback-библиотеку шейдеров: \(error)")
                    return
                }
            }
            
            // Получаем функции из библиотеки
            guard let vertexFunction = dynamicLibrary.makeFunction(name: "tvNoiseVertex"),
                  let fragmentFunction = dynamicLibrary.makeFunction(name: "tvNoiseFragment") else {
                print("Не удалось найти необходимые функции tvNoiseVertex или tvNoiseFragment в библиотеке шейдеров")
                return
            }
            
            // Создание дескриптора пайплайна рендеринга с оптимизацией
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            
            // Компиляция пайплайна
            do {
                renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            } catch {
                print("Не удалось скомпилировать пайплайн: \(error.localizedDescription)")
                return
            }
        }
        
        // Обновление uniform-данных - оптимизированный метод
        func updateUniforms() {
            let currentTime = CACurrentMediaTime()
            uniforms.time = Float(currentTime - startTime)
            uniforms.viewportSize = viewportSize
            uniforms.noiseIntensity = noiseIntensity
            uniforms.scanlineIntensity = scanlineIntensity
            uniforms.glitchIntensity = glitchIntensity
            uniforms.colorDistortion = colorDistortion
            
            // Копирование в буфер с обработкой ошибок
            if let uniformBuffer = uniformBuffer, uniformBuffer.length >= MemoryLayout<TVNoiseUniforms>.size {
                let uniformsPtr = uniformBuffer.contents()
                memcpy(uniformsPtr, &uniforms, MemoryLayout<TVNoiseUniforms>.size)
            }
        }
        
        // MARK: - MTKViewDelegate методы
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            viewportSize = SIMD2<Float>(Float(size.width), Float(size.height))
        }
        
        func draw(in view: MTKView) {
            guard
                let _ = device,
                let commandQueue = commandQueue,
                let drawable = view.currentDrawable,
                let renderPipelineState = renderPipelineState,
                let uniformBuffer = uniformBuffer
            else { return }
            
            // Обновление uniform-данных
            updateUniforms()
            
            // Создание command buffer с оптимизациями
            guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
            commandBuffer.label = "TVNoiseRenderPass"
            
            // Рендеринг только если можно получить корректный render pass
            if let renderPassDescriptor = view.currentRenderPassDescriptor,
               let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                
                renderEncoder.label = "TVNoiseRender"
                renderEncoder.setRenderPipelineState(renderPipelineState)
                renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
                renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
                renderEncoder.endEncoding()
            }
            
            // Отображение результата
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}

// MARK: - Модификатор эффекта сломанного ТВ
struct BrokenTVBackground: ViewModifier {
    @StateObject private var settings = TVEffectSettings()
    
    var noiseIntensity: Float
    var scanlineIntensity: Float
    var glitchIntensity: Float
    var colorDistortion: Float
    
    init(noiseIntensity: Float = 0.8, scanlineIntensity: Float = 0.5, glitchIntensity: Float = 0.6, colorDistortion: Float = 0.4) {
        self.noiseIntensity = noiseIntensity
        self.scanlineIntensity = scanlineIntensity
        self.glitchIntensity = glitchIntensity
        self.colorDistortion = colorDistortion
        
        // Настраиваем начальные параметры эффекта
        _settings = StateObject(wrappedValue: {
            let s = TVEffectSettings()
            s.noiseSize = Double(2.0 / noiseIntensity)
            s.scanLineDarkness = Double(1.0 - scanlineIntensity)
            s.useGlitches = glitchIntensity > 0.1
            s.glitchIntensity = Double(glitchIntensity)
            s.isColoredNoise = colorDistortion > 0.5
            s.useBlinking = true
            s.blinkingIntensity = Double(colorDistortion * 0.2)
            return s
        }())
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                BrokenTVEffectView(
                    noiseIntensity: noiseIntensity,
                    scanlineIntensity: scanlineIntensity,
                    glitchIntensity: glitchIntensity,
                    colorDistortion: colorDistortion
                )
                .ignoresSafeArea()
            )
    }
}

extension View {
    func brokenTVBackground(
        noiseIntensity: Float = 0.8,
        scanlineIntensity: Float = 0.5,
        glitchIntensity: Float = 0.6,
        colorDistortion: Float = 0.4
    ) -> some View {
        self.modifier(BrokenTVBackground(
            noiseIntensity: noiseIntensity,
            scanlineIntensity: scanlineIntensity,
            glitchIntensity: glitchIntensity,
            colorDistortion: colorDistortion
        ))
    }
}

// MARK: - Metal рендеринг

struct TVStaticView: UIViewRepresentable {
    var settings: TVEffectSettings
    
    // Добавим явный hashValue для отслеживания изменений настроек
    var hashValue: Int {
        var hasher = Hasher()
        hasher.combine(settings.isEnabled)
        hasher.combine(settings.refreshRate)
        hasher.combine(settings.noiseSize)
        hasher.combine(settings.useScanLines)
        hasher.combine(settings.scanLineDarkness)
        hasher.combine(settings.isColoredNoise)
        hasher.combine(settings.isHighContrast)
        hasher.combine(settings.useGlitches)
        hasher.combine(settings.glitchIntensity)
        hasher.combine(settings.useBlinking)
        hasher.combine(settings.blinkingIntensity)
        return hasher.finalize()
    }
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        // Безопасная проверка доступности Metal
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal не поддерживается на этом устройстве")
            return mtkView
        }
        
        // Настраиваем MTKView
        mtkView.device = device
        mtkView.backgroundColor = .black
        mtkView.framebufferOnly = true
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.delegate = context.coordinator
        
        // Устанавливаем частоту с ограничениями
        let safeRefreshRate = max(30, min(120, Int(settings.refreshRate)))
        mtkView.preferredFramesPerSecond = safeRefreshRate
        
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        
        // Инициализируем настройки асинхронно для предотвращения блокировок
        DispatchQueue.main.async {
            context.coordinator.initializeIfNeeded()
            context.coordinator.updateSettings(settings)
        }
        
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        // Убеждаемся, что coordinator инициализирован и настройки актуальны
        guard context.coordinator.isInitialized else {
            context.coordinator.initializeIfNeeded()
            return
        }
        
        // Обновляем частоту кадров только при существенном изменении
        if abs(Double(uiView.preferredFramesPerSecond) - settings.refreshRate) > 0.5 {
            uiView.preferredFramesPerSecond = max(30, min(120, Int(settings.refreshRate)))
        }
        
        // Принудительно обновляем все настройки при каждом изменении
        DispatchQueue.main.async {
            context.coordinator.updateSettings(settings)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var parent: TVStaticView
        var device: MTLDevice?
        var commandQueue: MTLCommandQueue?
        var renderPipelineState: MTLRenderPipelineState?
        var randomBuffer: MTLBuffer?
        var vertexBuffer: MTLBuffer?
        var viewportSizeBuffer: MTLBuffer?
        var settingsBuffer: MTLBuffer?
        var viewportSize: vector_uint2 = vector_uint2(0, 0)
        var currentSettings = ShaderSettings()
        var isInitialized = false
        
        // Для временных эффектов
        private var frameCounter: UInt32 = 0
        private var lastGlitchTime: TimeInterval = 0
        private var isGlitching = false
        private var glitchOffset: Float = 0
        private var blinkIntensity: Float = 0
        
        init(_ parent: TVStaticView) {
            self.parent = parent
            super.init()
            
            // Откладываем инициализацию Metal
            DispatchQueue.main.async {
                self.initializeIfNeeded()
            }
        }
        
        func initializeIfNeeded() {
            // Безопасная инициализация Metal только при необходимости
            guard !isInitialized, let mtkView = parent.settings.isEnabled ? (device == nil ? MTLCreateSystemDefaultDevice() : device) : nil else {
                return
            }
            
            self.device = mtkView
            
            guard let device = self.device,
                  let queue = device.makeCommandQueue() else {
                print("Не удалось создать command queue")
                return
            }
            
            self.commandQueue = queue
            
            do {
                try setupBuffers()
                try setupPipeline()
                isInitialized = true
            } catch {
                print("Ошибка инициализации Metal: \(error)")
            }
        }
        
        func setupBuffers() throws {
            guard let device = self.device else {
                throw NSError(domain: "TVStaticViewError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Metal устройство не инициализировано"])
            }
            
            // Создаем простой квадрат на весь экран
            let vertices: [Float] = [
                -1.0, -1.0, 0.0, 0.0, 1.0,   // левый нижний
                -1.0,  1.0, 0.0, 0.0, 0.0,   // левый верхний
                 1.0, -1.0, 0.0, 1.0, 1.0,   // правый нижний
                 1.0,  1.0, 0.0, 1.0, 0.0    // правый верхний
            ]
            
            guard let vBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size, options: []) else {
                throw NSError(domain: "TVStaticViewError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать vertex буфер"])
            }
            vertexBuffer = vBuffer
            
            // Буфер для размера вьюпорта
            guard let viewportBuffer = device.makeBuffer(length: MemoryLayout<vector_uint2>.size, options: []) else {
                throw NSError(domain: "TVStaticViewError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать viewport буфер"])
            }
            viewportSizeBuffer = viewportBuffer
            
            // Буфер для настроек шейдера
            var shaderSettings = ShaderSettings()
            currentSettings = shaderSettings
            guard let settingsBufferObj = device.makeBuffer(bytes: &shaderSettings, length: MemoryLayout<ShaderSettings>.size, options: []) else {
                throw NSError(domain: "TVStaticViewError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать settings буфер"])
            }
            settingsBuffer = settingsBufferObj
            
            // Создаем буфер для начального значения рандома
            var initialSeed: UInt32 = UInt32.random(in: 0..<UInt32.max)
            guard let randomBufferObj = device.makeBuffer(bytes: &initialSeed, length: MemoryLayout<UInt32>.size, options: []) else {
                throw NSError(domain: "TVStaticViewError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать random буфер"])
            }
            randomBuffer = randomBufferObj
        }
        
        // Структура для передачи настроек в шейдер
        struct ShaderSettings {
            var noiseSize: Float = 3.0 // Увеличенный размер по умолчанию
            var particleSpeed: Float = 1.0 // Скорость движения частиц
            var useScanLines: UInt32 = 1
            var scanLineDarkness: Float = 0.85
            var isColoredNoise: UInt32 = 0
            var isHighContrast: UInt32 = 1
            var useGlitches: UInt32 = 0
            var glitchIntensity: Float = 0.2
            var glitchOffset: Float = 0.0
            var useBlinking: UInt32 = 0
            var blinkingIntensity: Float = 0.0
            var frameCount: UInt32 = 0
        }
        
        // Обновление настроек шейдера
        func updateSettings(_ newSettings: TVEffectSettings) {
            guard isInitialized, let buffer = settingsBuffer else { return }
            
            // Создаем локальную копию настроек, чтобы избежать проблем с доступом к памяти
            let localNoiseSize = Float(newSettings.noiseSize)
            let localParticleSpeed = Float(newSettings.particleSpeed)
            let localUseScanLines = newSettings.useScanLines ? 1 : 0
            let localScanLineDarkness = Float(newSettings.scanLineDarkness) 
            let localIsColoredNoise = newSettings.isColoredNoise ? 1 : 0
            let localIsHighContrast = newSettings.isHighContrast ? 1 : 0
            let localUseGlitches = newSettings.useGlitches ? 1 : 0
            let localGlitchIntensity = Float(newSettings.glitchIntensity)
            let localUseBlinking = newSettings.useBlinking ? 1 : 0
            let localBlinkingIntensity = Float(newSettings.blinkingIntensity)
            
            var shaderSettings = ShaderSettings()
            shaderSettings.noiseSize = localNoiseSize
            shaderSettings.particleSpeed = localParticleSpeed
            shaderSettings.useScanLines = UInt32(localUseScanLines)
            shaderSettings.scanLineDarkness = localScanLineDarkness
            shaderSettings.isColoredNoise = UInt32(localIsColoredNoise)
            shaderSettings.isHighContrast = UInt32(localIsHighContrast) 
            shaderSettings.useGlitches = UInt32(localUseGlitches)
            shaderSettings.glitchIntensity = localGlitchIntensity
            shaderSettings.useBlinking = UInt32(localUseBlinking)
            shaderSettings.blinkingIntensity = localBlinkingIntensity
            
            // Сохраняем текущие настройки для отладки
            currentSettings = shaderSettings
            
            // Используем метод безопасного обновления буфера вместо прямого вызова memcpy
            updateBuffer(buffer, with: &shaderSettings)
        }
        
        func setupPipeline() throws {
            guard let device = self.device else {
                throw NSError(domain: "TVStaticViewError", code: 6, userInfo: [NSLocalizedDescriptionKey: "Metal устройство не инициализировано"])
            }
            
            // Шейдеры
            let shaderSource = """
            #include <metal_stdlib>
            using namespace metal;
            
            struct VertexIn {
                float2 position [[attribute(0)]];
                float2 texCoord [[attribute(1)]];
            };
            
            struct VertexOut {
                float4 position [[position]];
                float2 texCoord;
            };
            
            struct ShaderSettings {
                float noiseSize;
                float particleSpeed;
                uint useScanLines;
                float scanLineDarkness;
                uint isColoredNoise;
                uint isHighContrast;
                uint useGlitches;
                float glitchIntensity;
                float glitchOffset;
                uint useBlinking;
                float blinkingIntensity;
                uint frameCount;
            };
            
            // Вершинный шейдер просто передает координаты
            vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
                                          constant float *vertices [[buffer(0)]]) {
                VertexOut out;
                // Каждый вершина имеет 5 компонентов: x, y, z, u, v
                float2 position = float2(vertices[vertexID * 5], vertices[vertexID * 5 + 1]);
                float2 texCoord = float2(vertices[vertexID * 5 + 3], vertices[vertexID * 5 + 4]);
                
                out.position = float4(position, 0.0, 1.0);
                out.texCoord = texCoord;
                return out;
            }
            
            // Хороший быстрый случайный генератор для GPU
            float hash(float2 p, float seed) {
                float3 p3 = fract(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973) + seed);
                p3 += dot(p3, p3.yxz + 33.33);
                return fract((p3.x + p3.y) * p3.z);
            }
            
            // Генерация случайного цвета
            float3 randomColor(float2 coords, float seed) {
                float r = hash(coords, seed);
                float g = hash(coords + 0.1, seed);
                float b = hash(coords + 0.2, seed);
                return float3(r, g, b);
            }
            
            // Фрагментный шейдер генерирует шум
            fragment float4 fragmentShader(VertexOut in [[stage_in]],
                                          constant uint &randomSeed [[buffer(0)]],
                                          constant uint2 &viewportSize [[buffer(1)]],
                                          constant ShaderSettings &settings [[buffer(2)]]) {
                // Расчет координат с учетом размера шума
                // Учитываем скорость движения для анимации шума
                float timeOffset = float(settings.frameCount) * 0.01 * settings.particleSpeed;
                float2 scaledCoords = in.texCoord * float2(viewportSize) / settings.noiseSize;
                scaledCoords.y += timeOffset * 10.0; // Добавляем движение по вертикали с учетом скорости
                
                uint2 pixelCoords = uint2(scaledCoords);
                
                // Добавляем глитч-эффект, если он включен
                if (settings.useGlitches == 1 && settings.glitchOffset != 0) {
                    float glitchFactor = settings.glitchOffset * settings.glitchIntensity * 10.0;
                    
                    // Определяем, на каких строках появляется глитч
                    if (fract(in.texCoord.y * 20.0 + settings.frameCount * 0.01) < 0.2) {
                        scaledCoords.x += glitchFactor * hash(float2(in.texCoord.y, settings.frameCount), randomSeed);
                        pixelCoords = uint2(scaledCoords);
                    }
                }
                
                // Создаем шум
                float seed = float(randomSeed + settings.frameCount) / 4294967295.0;
                float3 color;
                
                if (settings.isColoredNoise == 1) {
                    // Цветной шум
                    color = randomColor(scaledCoords, seed);
                    
                    // Для высокой контрастности округляем значения цвета
                    if (settings.isHighContrast == 1) {
                        color = step(0.5, color);
                    }
                } else {
                    // Черно-белый шум
                    float rnd = hash(scaledCoords, seed);
                    
                    // Для высокой контрастности используем binarization
                    float value = (settings.isHighContrast == 1) ? step(0.5, rnd) : rnd;
                    color = float3(value);
                }
                
                // Применяем эффект scan lines
                if (settings.useScanLines == 1) {
                    uint py = uint(in.texCoord.y * viewportSize.y);
                    if (py % 2 == 0) {
                        color *= settings.scanLineDarkness;
                    }
                }
                
                // Добавляем эффект мерцания экрана
                if (settings.useBlinking == 1 && settings.blinkingIntensity > 0) {
                    float blinkFactor = hash(float2(0.0, settings.frameCount), seed) * settings.blinkingIntensity;
                    color *= (1.0 - blinkFactor);
                }
                
                return float4(color, 1.0);
            }
            """
            
            // Компилируем шейдер с безопасным хендлингом ошибок
            let library: MTLLibrary
            do {
                library = try compileShaders(source: shaderSource, device: device)
            } catch {
                print("Ошибка создания библиотеки: \(error)")
                throw error
            }
            
            // Получаем функции из шейдера
            guard let vertexFunction = library.makeFunction(name: "vertexShader"),
                  let fragmentFunction = library.makeFunction(name: "fragmentShader") else {
                throw NSError(domain: "TVStaticViewError", code: 7, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать функции шейдера"])
            }
            
            // Описываем вершинный формат
            let vertexDescriptor = MTLVertexDescriptor()
            vertexDescriptor.attributes[0].format = .float2
            vertexDescriptor.attributes[0].offset = 0
            vertexDescriptor.attributes[0].bufferIndex = 0
            
            vertexDescriptor.attributes[1].format = .float2
            vertexDescriptor.attributes[1].offset = 3 * MemoryLayout<Float>.size
            vertexDescriptor.attributes[1].bufferIndex = 0
            
            vertexDescriptor.layouts[0].stride = 5 * MemoryLayout<Float>.size
            vertexDescriptor.layouts[0].stepRate = 1
            vertexDescriptor.layouts[0].stepFunction = .perVertex
            
            // Создаем pipeline state
            let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
            pipelineStateDescriptor.vertexFunction = vertexFunction
            pipelineStateDescriptor.fragmentFunction = fragmentFunction
            pipelineStateDescriptor.vertexDescriptor = vertexDescriptor
            pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            do {
                renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
            } catch {
                print("Не удалось создать render pipeline state: \(error)")
                throw error
            }
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Отменяем обновление, если не инициализированы
            guard isInitialized, let buffer = viewportSizeBuffer else { return }
            
            // Обновляем размер вьюпорта
            viewportSize.x = UInt32(size.width)
            viewportSize.y = UInt32(size.height)
            
            // Используем метод безопасного обновления буфера
            updateBuffer(buffer, with: &viewportSize)
        }
        
        func draw(in view: MTKView) {
            // Проверяем что все настроено
            guard isInitialized, 
                  let renderPipelineState = renderPipelineState,
                  let commandQueue = commandQueue,
                  let drawable = view.currentDrawable,
                  let commandBuffer = commandQueue.makeCommandBuffer(),
                  let renderPassDescriptor = view.currentRenderPassDescriptor,
                  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                return
            }
            
            // Если размер вьюпорта еще не установлен, установим его сейчас
            if viewportSize.x == 0 || viewportSize.y == 0, let buffer = viewportSizeBuffer {
                viewportSize.x = UInt32(view.drawableSize.width)
                viewportSize.y = UInt32(view.drawableSize.height)
                
                // Используем метод безопасного обновления буфера
                updateBuffer(buffer, with: &viewportSize)
            }
            
            // Обновляем счетчик кадров
            frameCounter += 1
            
            // Управление временными эффектами (глитчи и мерцание)
            let currentTime = ProcessInfo.processInfo.systemUptime
            
            // Проверяем, нужно ли активировать глитч
            if parent.settings.useGlitches {
                if !isGlitching && currentTime - lastGlitchTime > Double.random(in: 1.0...3.0) {
                    isGlitching = true
                    glitchOffset = Float.random(in: -1.0...1.0)
                    lastGlitchTime = currentTime
                } else if isGlitching && currentTime - lastGlitchTime > Double.random(in: 0.05...0.2) {
                    isGlitching = false
                    glitchOffset = 0
                }
            } else {
                isGlitching = false
                glitchOffset = 0
            }
            
            // Обновляем буфер настроек с текущими значениями эффектов
            if let buffer = settingsBuffer {
                var settings = currentSettings
                settings.frameCount = frameCounter
                settings.glitchOffset = glitchOffset
                
                // Используем метод безопасного обновления буфера
                updateBuffer(buffer, with: &settings)
            }
            
            // Обновляем seed для рандома, чтобы шум менялся каждый кадр
            if let buffer = randomBuffer {
                var newSeed = UInt32.random(in: 0..<UInt32.max)
                
                // Используем метод безопасного обновления буфера вместо прямого вызова memcpy
                updateBuffer(buffer, with: &newSeed)
            }
            
            // Запускаем рендер
            renderEncoder.setRenderPipelineState(renderPipelineState)
            
            if let vertexBuffer = vertexBuffer {
                renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            }
            
            if let randomBuffer = randomBuffer {
                renderEncoder.setFragmentBuffer(randomBuffer, offset: 0, index: 0)
            }
            
            if let viewportSizeBuffer = viewportSizeBuffer {
                renderEncoder.setFragmentBuffer(viewportSizeBuffer, offset: 0, index: 1)
            }
            
            if let settingsBuffer = settingsBuffer {
                renderEncoder.setFragmentBuffer(settingsBuffer, offset: 0, index: 2)
            }
            
            // Отрисовываем квадрат
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            renderEncoder.endEncoding()
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}

// MARK: - Модификатор эффекта сломанного ТВ
struct BrokenTVEffectModifier: ViewModifier {
    @AppStorage("useParticleEffect") private var useParticleEffect = true
    @State private var settings = TVEffectSettings()
    
    func body(content: Content) -> some View {
        ZStack {
            if useParticleEffect {
                TVStaticView(settings: settings)
                    .ignoresSafeArea() // Игнорируем безопасную зону для покрытия всего экрана
            }
            
            content
        }
    }
}

// Главное расширение для View
extension View {
    func brokenTVEffect() -> some View {
        self.modifier(BrokenTVEffectModifier())
    }
}

// Экран настроек эффекта ТВ
struct TVEffectSettingsView: View {
    @StateObject private var settings = TVEffectSettings()
    @Environment(\.dismiss) private var dismiss
    var viewModel: (any TranslationProvider)?
    
    // Добавляем метод для получения переводов, который безопасно использует viewModel
    private func getTranslation(for key: String) -> String {
        return viewModel?.getTranslation(for: key) ?? key
    }
    
    var body: some View {
        Form {
            // Основные настройки
            Section(header: Text(getTranslation(for: "brokenTvEffectTitle"))) {
                // Размер точек
                VStack(alignment: .leading) {
                    Text("\(getTranslation(for: "pointSize")): \(String(format: "%.1f", settings.noiseSize))x")
                    Slider(value: $settings.noiseSize, in: 1.0...10.0, step: 0.5)
                }
                
                // Информация об оптимизации
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.yellow)
                    Text(getTranslation(for: "optimizedFor120Hz"))
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
            }
        }
        .navigationTitle(getTranslation(for: "brokenTvEffectSettings"))
        .preferredColorScheme(.dark)
    }
}

// MARK: - Функция для обработки ошибок Metal
private func handleMetalError(_ error: Error) {
    #if DEBUG
    print("Metal ошибка: \(error.localizedDescription)")
    #endif
    
    // Отправляем уведомление, чтобы переключиться на запасной эффект
    DispatchQueue.main.async {
        NotificationCenter.default.post(name: NSNotification.Name("MetalRenderingError"), object: nil)
    }
}

// MARK: - Создание компилятора Metal
private func compileShaders(source: String, device: MTLDevice) throws -> MTLLibrary {
    let options = MTLCompileOptions()
    // Исправляем deprecated свойство
    #if os(iOS) && compiler(>=5.9)
    if #available(iOS 18.0, *) {
        options.mathMode = .fast
    } else {
        options.fastMathEnabled = true
    }
    #else
    options.fastMathEnabled = true
    #endif
    
    return try device.makeLibrary(source: source, options: options)
}

// MARK: - Безопасное обновление буфера
private func updateBuffer<T>(_ buffer: MTLBuffer?, with data: inout T) where T: Sendable {
    guard let buffer = buffer else { return }
    
    withUnsafeBytes(of: &data) { rawBufferPointer in
    let bufferPointer = buffer.contents()
        memcpy(bufferPointer, rawBufferPointer.baseAddress, MemoryLayout<T>.size)
    }
}

private func createBuffer<T>(_ data: [T], device: MTLDevice) -> MTLBuffer? where T: Sendable {
    let size = data.count * MemoryLayout<T>.size
    
    if let buffer = device.makeBuffer(length: size, options: []) {
        data.withUnsafeBytes { rawBufferPointer in
            let bufferPointer = buffer.contents()
            memcpy(bufferPointer, rawBufferPointer.baseAddress, size)
        }
        return buffer
    }
    
    return nil
}

