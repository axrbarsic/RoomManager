import SwiftUI
import MetalKit
import Metal
import simd

// MARK: - Структуры данных для цифр
struct DigitalSymbol {
    var position: SIMD2<Float>
    var velocity: SIMD2<Float>
    var size: Float
    var color: SIMD4<Float>
    var value: UInt32 // значение символа (0-9)
    var opacity: Float
    var lifeTime: Float
}

struct DigitalUniforms {
    var count: UInt32
    var viewportSize: SIMD2<Float>
    var time: Float
    var colorScheme: UInt32
    var deltaTime: Float
    var padding: Float
}

// MARK: - Metal View SwiftUI обертка
struct DigitalRainView: UIViewRepresentable {
    var symbolCount: Int = 300  // Количество цифр по умолчанию
    var colorScheme: Int = 1 // По умолчанию зеленый
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 60
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0.3)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = true
        mtkView.layer.isOpaque = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.presentsWithTransaction = false
        
        // Настройка устройства Metal
        if let device = MTLCreateSystemDefaultDevice() {
            mtkView.device = device
            // Инициализация рендера в координаторе
            context.coordinator.setupRenderer(device: device, view: mtkView)
        } else {
            print("Metal не поддерживается на этом устройстве, пропуск инициализации эффекта DigitalRainView")
            return mtkView
        }
        
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.symbolCount = symbolCount
        context.coordinator.colorScheme = colorScheme
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(symbolCount: symbolCount, colorScheme: colorScheme)
    }
    
    // MARK: - Координатор/Delegate для MTKView
    class Coordinator: NSObject, MTKViewDelegate {
        var symbolCount: Int
        var colorScheme: Int
        
        // Metal объекты
        var device: MTLDevice?
        var commandQueue: MTLCommandQueue?
        var pipelineState: MTLRenderPipelineState?
        var symbolBuffer: MTLBuffer?
        var uniformBuffer: MTLBuffer?
        var computePipelineState: MTLComputePipelineState?
        var texture: MTLTexture?
        
        // Данные о состоянии
        var symbols: [DigitalSymbol] = []
        var uniforms = DigitalUniforms(
            count: 0,
            viewportSize: SIMD2<Float>(0, 0),
            time: 0,
            colorScheme: 0,
            deltaTime: 0,
            padding: 0
        )
        var viewportSize = SIMD2<Float>(0, 0)
        var startTime = CFAbsoluteTimeGetCurrent()
        var lastFrameTime = CFAbsoluteTimeGetCurrent()
        
        init(symbolCount: Int, colorScheme: Int) {
            self.symbolCount = symbolCount
            self.colorScheme = colorScheme
            super.init()
        }
        
        // Настройка рендерера Metal
        func setupRenderer(device: MTLDevice, view: MTKView) {
            self.device = device
            commandQueue = device.makeCommandQueue()
            
            // Создание текстуры с цифрами
            createDigitsTexture(device: device)
            
            // Создание шейдеров
        let library: MTLLibrary
        do {
            // Создаем библиотеку из исходного кода
            let shaderSource = self.metalShaderSource()
            library = try device.makeLibrary(source: shaderSource, options: nil)
        } catch {
            print("Не удалось создать библиотеку Metal: \(error)")
            return
        }
            
        guard
            let vertexFunction = library.makeFunction(name: "digitalVertex"),
            let fragmentFunction = library.makeFunction(name: "digitalFragment"),
            let updateFunction = library.makeFunction(name: "updateDigitals")
        else {
            print("Не удалось найти функции digitalVertex, digitalFragment или updateDigitals в библиотеке Metal")
            return
        }
            
            // Настройка pipeline для рендеринга
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
            
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Не удалось создать render pipeline state: \(error)")
            return
        }

        // Настройка compute pipeline для обновления символов
        do {
            computePipelineState = try device.makeComputePipelineState(function: updateFunction)
        } catch {
            print("Не удалось создать compute pipeline state: \(error)")
            return
        }
            
            // Создание буферов
            createBuffers(device: device)
        }
        
        // Создание текстуры с цифрами
        func createDigitsTexture(device: MTLDevice) {
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm,
                width: 100,  // 10 цифр по 10 пикселей ширины
                height: 10,
                mipmapped: false
            )
            textureDescriptor.usage = [.shaderRead, .renderTarget]
            
            guard let newTexture = device.makeTexture(descriptor: textureDescriptor) else {
                print("Не удалось создать текстуру")
                return
            }
            
            texture = newTexture
            
            // Создаем простое представление цифр (белые цифры на прозрачном фоне)
            let region = MTLRegionMake2D(0, 0, 100, 10)
            let bytesPerRow = 4 * 100
            
            // Создаем массив данных для текстуры (RGBA, 8 бит на канал)
            var textureData = [UInt8](repeating: 0, count: 100 * 10 * 4)
            
            // Заполняем данные текстуры
            for digit in 0..<10 {
                for y in 0..<10 {
                    for x in 0..<10 {
                        let index = (y * 100 + digit * 10 + x) * 4
                        
                        // Простые цифровые представления (можно заменить на более сложные)
                        var isDigitPixel = false
                        
                        switch digit {
                        case 0: // 0
                            isDigitPixel = (x == 2 || x == 7 || y == 1 || y == 8) || 
                                          ((x == 7 && y == 7) || (x == 2 && y == 2))
                        case 1: // 1
                            isDigitPixel = x == 5 || (y == 8 && x > 2 && x < 8)
                        case 2: // 2
                            isDigitPixel = (y == 1 || y == 4 || y == 8) || 
                                          (y < 4 && x == 7) || (y > 4 && x == 2)
                        case 3: // 3
                            isDigitPixel = (y == 1 || y == 4 || y == 8) || x == 7
                        case 4: // 4
                            isDigitPixel = (x == 2 && y < 5) || x == 7 || (y == 4)
                        case 5: // 5
                            isDigitPixel = (y == 1 || y == 4 || y == 8) || 
                                          (y < 4 && x == 2) || (y > 4 && x == 7)
                        case 6: // 6
                            isDigitPixel = (y == 1 || y == 4 || y == 8) || x == 2 || 
                                          (y > 4 && x == 7)
                        case 7: // 7
                            isDigitPixel = y == 1 || x == 7
                        case 8: // 8
                            isDigitPixel = (y == 1 || y == 4 || y == 8) || x == 2 || x == 7
                        case 9: // 9
                            isDigitPixel = (y == 1 || y == 4 || y == 8) || x == 7 || 
                                          (y < 4 && x == 2)
                        default:
                            break
                        }
                        
                        if isDigitPixel {
                            textureData[index] = 255     // R
                            textureData[index + 1] = 255 // G
                            textureData[index + 2] = 255 // B
                            textureData[index + 3] = 255 // A
                        }
                    }
                }
            }
            
            // Загружаем данные в текстуру
            newTexture.replace(region: region, mipmapLevel: 0, withBytes: &textureData, bytesPerRow: bytesPerRow)
        }
        
        // Создание буферов для данных
        func createBuffers(device: MTLDevice) {
            // Инициализация символов
            initializeSymbols()
            
            // Создание буфера для символов
            let symbolBufferSize = symbols.count * MemoryLayout<DigitalSymbol>.stride
            symbolBuffer = device.makeBuffer(bytes: &symbols, length: symbolBufferSize, options: [])
            
            // Создание буфера для uniform-данных
            uniformBuffer = device.makeBuffer(length: MemoryLayout<DigitalUniforms>.size, options: [])
        }
        
        // Инициализация символов
        func initializeSymbols() {
            symbols = []
            
            // Проверка на корректные размеры viewport
            let safeWidth = max(viewportSize.x, 100.0)
            let safeHeight = max(viewportSize.y, 100.0)
            
            // Цвета схем
            let colors: [SIMD4<Float>] = [
                SIMD4<Float>(1.0, 1.0, 1.0, 0.8),         // Белый
                SIMD4<Float>(0.2, 0.8, 0.3, 0.8),         // Зеленый (для эффекта Матрицы)
                SIMD4<Float>(0.3, 0.8, 1.0, 0.8),         // Голубой
                SIMD4<Float>(1.0, 0.8, 0.2, 0.8),         // Желтый
                SIMD4<Float>(0.8, 0.4, 1.0, 0.8)          // Фиолетовый
            ]
            
            let defaultColor = colors[min(colorScheme, colors.count - 1)]
            
            // Предварительно выделяем память
            symbols.reserveCapacity(symbolCount)
            
            // Распределяем символы по всей высоте экрана для мгновенного заполнения
            for _ in 0..<symbolCount {
                let posX = Float.random(in: 0...safeWidth)
                // Используем всю высоту экрана плюс дополнительное пространство сверху
                let posY = Float.random(in: -safeHeight...safeHeight * 2)
                
                // Различные размеры для добавления глубины
                let size = Float.random(in: 7...15)
                
                // Случайные цифры от 0 до 9
                let symbolValue = UInt32.random(in: 0...9)
                
                // Различная прозрачность для создания глубины
                let opacity = Float.random(in: 0.3...1.0)
                
                // Скорость в основном направлена вниз, увеличиваем минимальную скорость
                let velY = Float.random(in: 15...35)
                let velX = Float.random(in: -5...5)
                
                // Разное время жизни для символов
                let lifeTime = Float.random(in: 0...10.0)
                
                let symbol = DigitalSymbol(
                    position: SIMD2<Float>(posX, posY),
                    velocity: SIMD2<Float>(velX, velY),
                    size: size,
                    color: defaultColor,
                    value: symbolValue,
                    opacity: opacity,
                    lifeTime: lifeTime
                )
                symbols.append(symbol)
            }
        }
        
        // Обновление uniform-данных
        func updateUniforms() {
            let currentTime = CFAbsoluteTimeGetCurrent()
            let elapsedTime = Float(currentTime - startTime)
            
            uniforms.count = UInt32(symbols.count)
            uniforms.viewportSize = viewportSize
            uniforms.time = elapsedTime
            uniforms.colorScheme = UInt32(colorScheme)
            
            // Расчет deltaTime с ограничением для стабильности
            let rawDeltaTime = Float(currentTime - lastFrameTime)
            uniforms.deltaTime = min(rawDeltaTime, 1.0 / 30.0)
            lastFrameTime = currentTime
            
            // Копирование в буфер
            if let uniformsPtr = uniformBuffer?.contents() {
                memcpy(uniformsPtr, &uniforms, MemoryLayout<DigitalUniforms>.size)
            }
        }
        
        // MARK: - MTKViewDelegate методы
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            viewportSize = SIMD2<Float>(Float(size.width), Float(size.height))
            
            // Переинициализируем символы при изменении размера
            if !symbols.isEmpty && viewportSize.x > 0 && viewportSize.y > 0 {
                initializeSymbols()
                
                let symbolBufferSize = symbols.count * MemoryLayout<DigitalSymbol>.stride
                if let symbolBuffer = symbolBuffer, symbolBuffer.length >= symbolBufferSize {
                    let symbolsPtr = symbolBuffer.contents()
                    memcpy(symbolsPtr, &symbols, symbolBufferSize)
                } else {
                    // Создаем новый буфер, если нужен больший размер
                    symbolBuffer = device?.makeBuffer(bytes: &symbols, length: symbolBufferSize, options: [])
                }
            }
        }
        
        func draw(in view: MTKView) {
            guard
                let commandQueue = commandQueue,
                let drawable = view.currentDrawable,
                let pipelineState = pipelineState,
                let symbolBuffer = symbolBuffer,
                let uniformBuffer = uniformBuffer,
                let computePipelineState = computePipelineState,
                let texture = texture
            else { return }
            
            // Обновление uniform-данных
            updateUniforms()
            
            // Создание command buffer
            guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
            commandBuffer.label = "DigitalRainPass"
            
            // Используем compute shader для обновления положения цифр
            if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
                computeEncoder.label = "DigitalCompute"
                computeEncoder.setComputePipelineState(computePipelineState)
                computeEncoder.setBuffer(symbolBuffer, offset: 0, index: 0)
                computeEncoder.setBuffer(uniformBuffer, offset: 0, index: 1)
                
                // Распределение работы
                let gridSize = MTLSize(width: symbols.count, height: 1, depth: 1)
                let threadGroupSize = MTLSize(
                    width: min(symbols.count, computePipelineState.maxTotalThreadsPerThreadgroup),
                    height: 1,
                    depth: 1
                )
                
                computeEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)
                computeEncoder.endEncoding()
            }
            
            // Рендеринг
            if let renderPassDescriptor = view.currentRenderPassDescriptor,
               let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                
                renderEncoder.label = "DigitalRain"
                renderEncoder.setRenderPipelineState(pipelineState)
                renderEncoder.setVertexBuffer(symbolBuffer, offset: 0, index: 0)
                renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
                renderEncoder.setFragmentTexture(texture, index: 0)
                renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
                
                // Рендеринг каждой цифры как спрайта
                renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: symbols.count)
                
                renderEncoder.endEncoding()
            }
            
            // Отображение результата
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
        
        // MARK: - Источник шейдеров Metal
        func metalShaderSource() -> String {
            """
            #include <metal_stdlib>
            using namespace metal;
            
            struct DigitalSymbol {
                float2 position;
                float2 velocity;
                float size;
                float4 color;
                uint value;
                float opacity;
                float lifeTime;
            };
            
            struct DigitalUniforms {
                uint count;
                float2 viewportSize;
                float time;
                uint colorScheme;
                float deltaTime;
                float padding;
            };
            
            struct VertexOut {
                float4 position [[position]];
                float2 texCoord;
                float4 color;
                uint value;
            };
            
            // Функция для генерации псевдослучайных чисел
            float random(uint2 p) {
                // Преобразуем uint2 в float2 перед использованием функции dot
                float2 fp = float2(p);
                return fract(sin(dot(fp, float2(12.9898, 78.233))) * 43758.5453);
            }
            
            // Вершинный шейдер для цифр
            vertex VertexOut digitalVertex(uint vertexID [[vertex_id]],
                                        uint instanceID [[instance_id]],
                                        constant DigitalSymbol* symbols [[buffer(0)]],
                                        constant DigitalUniforms& uniforms [[buffer(1)]]) {
                float2 vertices[4] = {
                    float2(-0.5, -0.5),
                    float2(0.5, -0.5),
                    float2(-0.5, 0.5),
                    float2(0.5, 0.5)
                };
                
                float2 texCoords[4] = {
                    float2(0.0, 1.0),
                    float2(1.0, 1.0),
                    float2(0.0, 0.0),
                    float2(1.0, 0.0)
                };
                
                DigitalSymbol symbol = symbols[instanceID];
                
                VertexOut out;
                
                // Вычисляем позицию для вершины с учетом размера спрайта
                float2 spritePosition = vertices[vertexID] * symbol.size;
                float2 worldPosition = symbol.position + spritePosition;
                
                // Нормализуем в координаты экрана (-1,1)
                float2 normalizedPosition = float2(
                    2.0 * worldPosition.x / uniforms.viewportSize.x - 1.0,
                    1.0 - 2.0 * worldPosition.y / uniforms.viewportSize.y
                );
                
                out.position = float4(normalizedPosition, 0.0, 1.0);
                
                // Вычисляем текстурные координаты с учетом значения символа
                float2 adjustedTexCoord = texCoords[vertexID];
                adjustedTexCoord.x = (symbol.value * 0.1) + (adjustedTexCoord.x * 0.1); // 10 цифр в текстуре
                
                out.texCoord = adjustedTexCoord;
                
                // Пульсирующий эффект, зависящий от времени
                float pulseEffect = 0.8 + 0.2 * sin(uniforms.time + symbol.lifeTime * 2.0);
                
                // Цвет, модифицированный схемой
                float4 baseColor = symbol.color;
                switch (uniforms.colorScheme) {
                    case 0: // Белый
                        baseColor = float4(1.0, 1.0, 1.0, symbol.opacity);
                        break;
                    case 1: // Зеленый (Матрица)
                        baseColor = float4(0.2, 0.8 * pulseEffect, 0.3, symbol.opacity);
                        break;
                    case 2: // Голубой
                        baseColor = float4(0.3, 0.7, 1.0 * pulseEffect, symbol.opacity);
                        break;
                    case 3: // Желтый
                        baseColor = float4(1.0 * pulseEffect, 0.8, 0.2, symbol.opacity);
                        break;
                    case 4: // Фиолетовый
                        baseColor = float4(0.8, 0.4, 1.0 * pulseEffect, symbol.opacity);
                        break;
                }
                
                // Эффект "головы" колонны - более яркий символ
                if (symbol.lifeTime < 1.0) {
                    baseColor.rgb *= 1.5;
                }
                
                out.color = baseColor;
                out.value = symbol.value;
                
                return out;
            }
            
            // Фрагментный шейдер для цифр
            fragment float4 digitalFragment(VertexOut in [[stage_in]],
                                         texture2d<float> digitTexture [[texture(0)]],
                                         constant DigitalUniforms& uniforms [[buffer(0)]]) {
                // Сэмплирование текстуры цифры
                constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
                float4 texColor = digitTexture.sample(textureSampler, in.texCoord);
                
                // Применяем цвет символа к текстуре
                float4 finalColor = texColor * in.color;
                
                // Добавляем свечение для создания эффекта лазерного текста
                float glow = 0.3;
                
                // Базовое свечение
                float4 glowColor = in.color * glow;
                
                // Финальный цвет с учетом свечения
                finalColor = mix(glowColor, finalColor, texColor.a);
                
                return finalColor;
            }
            
            // Compute шейдер для обновления позиций
            kernel void updateDigitals(device DigitalSymbol* symbols [[buffer(0)]],
                                     constant DigitalUniforms& uniforms [[buffer(1)]],
                                     uint id [[thread_position_in_grid]]) {
                if (id >= uniforms.count) return;
                
                DigitalSymbol symbol = symbols[id];
                
                // Обновляем время жизни
                symbol.lifeTime += uniforms.deltaTime;
                
                // Обновляем позицию
                symbol.position += symbol.velocity * uniforms.deltaTime;
                
                // Проверка границ экрана
                if (symbol.position.y > uniforms.viewportSize.y + symbol.size) {
                    // Если вышли за нижнюю границу, перемещаем вверх
                    symbol.position.y = -symbol.size;
                    symbol.position.x = float(random(uint2(id, uint(uniforms.time * 1000))) * uniforms.viewportSize.x);
                    symbol.opacity = 0.3 + 0.7 * random(uint2(id + 1, uint(uniforms.time * 1000)));
                    symbol.lifeTime = 0.0; // Сбрасываем время жизни
                    
                    // Случайно меняем цифру
                    if (random(uint2(id + 2, uint(uniforms.time * 1000))) < 0.3) {
                        symbol.value = uint(random(uint2(id + 3, uint(uniforms.time * 1000))) * 10);
                    }
                }
                
                // Случайное изменение цифры со временем
                if (random(uint2(id, uint(symbol.lifeTime * 100 + uniforms.time * 1000))) < 0.01) {
                    symbol.value = uint(random(uint2(id + 5, uint(uniforms.time * 1000))) * 10);
                }
                
                // Сохраняем обновленный символ
                symbols[id] = symbol;
            }
            """
        }
    }
}

// SwiftUI модификатор для добавления фона с цифрами
struct DigitalRainBackground: ViewModifier {
    var symbolCount: Int = 500 // Увеличиваем количество символов по умолчанию
    var colorScheme: Int = 1 // По умолчанию зеленый (Matrix style)
    
    func body(content: Content) -> some View {
        content
            .background(
                DigitalRainView(
                    symbolCount: symbolCount,
                    colorScheme: colorScheme
                )
                .ignoresSafeArea()
            )
    }
}

extension View {
    func digitalRainBackground(
        symbolCount: Int = 500, // Увеличиваем количество символов по умолчанию
        colorScheme: Int = 1
    ) -> some View {
        self.modifier(DigitalRainBackground(
            symbolCount: symbolCount,
            colorScheme: colorScheme
        ))
    }
} 