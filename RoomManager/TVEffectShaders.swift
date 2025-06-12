import Foundation
import Metal

/// Коллекция Metal шейдеров для эффекта сломанного ТВ
struct TVEffectShaders {
    
    // MARK: - Optimized TV Noise Shader
    static let optimizedTVNoiseShader = """
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
    
    // MARK: - Static Noise Shader
    static let staticNoiseShader = """
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
    
    // MARK: - Fallback Shader
    static let fallbackShader = """
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
    
    // MARK: - Helper Methods
    static func compileShader(source: String, device: MTLDevice) throws -> MTLLibrary {
        let options = MTLCompileOptions()
        
        // Используем современный API для математических операций
        if #available(iOS 18.0, *) {
            options.mathMode = .fast
        } else {
            #if !targetEnvironment(simulator)
            options.fastMathEnabled = true
            #endif
        }
        
        return try device.makeLibrary(source: source, options: options)
    }
    
    static func createFallbackLibrary(device: MTLDevice) -> MTLLibrary? {
        do {
            return try compileShader(source: fallbackShader, device: device)
        } catch {
            return nil
        }
    }
} 