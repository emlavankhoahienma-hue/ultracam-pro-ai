#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct VertexIn {
    float2 position;
    float2 texCoords;
};

struct MetalVertexOut {
    float4 position [[position]];
    float2 texCoords;
};

struct DistortionUniforms {
    float zoomFactor;           // Range: 0.5 to 5.0 (Shader active when < 1.0)
    float distortionStrength;   // Distortion curvature factor (default: ~0.45)
    float k1;                   // Primary barrel coefficient (default: -0.28)
    float k2;                   // Secondary barrel coefficient (default: 0.08)
    float aspectRatio;          // Frame width / height ratio
    float edgeFeathering;       // Border transition smoothing (0.0 to 1.0)
    float vignetteIntensity;    // Corner vignette correction (0.0 to 1.0)
    float chromaticAberration;  // RGB channel dispersion correction
    int lutPresetIndex;         // 0: Normal, 1: Fuji, 2: Portra, 3: Leica B&W, 4: CineStill, 5: TealOrange
    float lutIntensity;         // 0.0 to 1.0
    float cinematicBlurRadius;  // 0.0 (off) to 15.0 (max bokeh)
    int hasSegmentationMask;    // 1 if mask is bound, 0 otherwise
};

// MARK: - Color Grading 3D Film LUT Functions
inline float3 applyColorLUT(float3 color, int presetIndex, float intensity) {
    if (presetIndex == 0 || intensity <= 0.001) {
        return color;
    }
    
    float3 graded = color;
    
    // Preset 1: Fuji Classic Chrome (Soft highlights, deep cinematic greens, rich shadows)
    if (presetIndex == 1) {
        graded.r = pow(color.r, 1.08) * 0.96 + 0.02;
        graded.g = pow(color.g, 0.98) * 1.02;
        graded.b = pow(color.b, 1.05) * 0.94;
        float luma = dot(graded, float3(0.299, 0.587, 0.114));
        graded = mix(float3(luma), graded, 0.85); // Muted saturation
    }
    // Preset 2: Kodak Portra 400 (Warm golden skin tones, pastel highlights, creamy contrast)
    else if (presetIndex == 2) {
        graded.r = color.r * 1.08 + 0.03;
        graded.g = color.g * 1.02 + 0.01;
        graded.b = color.b * 0.92;
        graded = pow(clamp(graded, 0.0, 1.0), float3(0.95, 0.98, 1.05));
    }
    // Preset 3: Leica Monochrome (Analog black and white, deep tonal gradient)
    else if (presetIndex == 3) {
        float luma = dot(color, float3(0.26, 0.65, 0.09));
        float contrast = (luma - 0.5) * 1.25 + 0.5;
        graded = float3(clamp(contrast, 0.0, 1.0));
    }
    // Preset 4: Cinestill 800T (Tungsten glow, electric blues, warm halation)
    else if (presetIndex == 4) {
        graded.r = color.r * 1.15 + (pow(color.r, 2.5) * 0.12);
        graded.g = color.g * 0.98;
        graded.b = color.b * 1.12 + 0.02;
    }
    // Preset 5: Teal & Orange (Hollywood cinematic split tone)
    else if (presetIndex == 5) {
        float luma = dot(color, float3(0.299, 0.587, 0.114));
        float3 shadows = float3(0.0, 0.65, 0.85); // Teal
        float3 highlights = float3(1.05, 0.70, 0.20); // Orange
        graded = mix(shadows * luma * 1.4, highlights, smoothstep(0.25, 0.85, luma));
        graded = mix(color, graded, 0.70);
    }
    
    return mix(color, clamp(graded, 0.0, 1.0), intensity);
}

// MARK: - Vertex Shader
vertex MetalVertexOut ultraWideVertexShader(uint vertexID [[vertex_id]],
                                            constant VertexIn *vertices [[buffer(0)]]) {
    MetalVertexOut out;
    out.position = float4(vertices[vertexID].position, 0.0, 1.0);
    out.texCoords = vertices[vertexID].texCoords;
    return out;
}

// MARK: - Fragment Shader: 0.5x Barrel Distortion + LUT Color + Cinematic Bokeh
fragment float4 ultraWideFragmentShader(MetalVertexOut in [[stage_in]],
                                        texture2d<float, access::sample> inTexture [[texture(0)]],
                                        texture2d<float, access::sample> maskTexture [[texture(1)]],
                                        constant DistortionUniforms &uniforms [[buffer(0)]]) {
    constexpr sampler textureSampler(coord::normalized,
                                     address::clamp_to_edge,
                                     filter::linear,
                                     mip_filter::linear);

    float zoom = uniforms.zoomFactor;
    float2 uv = in.texCoords;
    float4 sampledColor;

    // MARK: - 1. 0.5x Barrel Distortion & FoV Expansion
    if (zoom < 1.0) {
        float aspect = uniforms.aspectRatio > 0.0 ? uniforms.aspectRatio : (9.0 / 16.0);
        float2 centered = (uv - float2(0.5, 0.5));
        centered.x *= aspect;

        float r = length(centered);
        float t = clamp((1.0 - zoom) / 0.5, 0.0, 1.0);
        float k1 = uniforms.k1 * t;
        float k2 = uniforms.k2 * t;

        float r2 = r * r;
        float r4 = r2 * r2;
        float distortionScale = 1.0 + k1 * r2 + k2 * r4;

        float fovScale = mix(1.0, zoom, t * 0.95);
        float2 distortedCentered = centered * distortionScale * fovScale;
        distortedCentered.x /= aspect;
        float2 sampleUV = distortedCentered + float2(0.5, 0.5);

        float edgeDistX = min(sampleUV.x, 1.0 - sampleUV.x);
        float edgeDistY = min(sampleUV.y, 1.0 - sampleUV.y);
        float minEdgeDist = min(edgeDistX, edgeDistY);
        
        float caShift = 0.0025 * t * (r * 1.5);
        float2 redUV   = sampleUV + (distortedCentered * caShift);
        float2 blueUV  = sampleUV - (distortedCentered * caShift);
        float2 greenUV = sampleUV;

        float4 colorR = inTexture.sample(textureSampler, clamp(redUV, 0.0, 1.0));
        float4 colorG = inTexture.sample(textureSampler, clamp(greenUV, 0.0, 1.0));
        float4 colorB = inTexture.sample(textureSampler, clamp(blueUV, 0.0, 1.0));

        sampledColor = float4(colorR.r, colorG.g, colorB.b, 1.0);

        float vignette = 1.0 - (uniforms.vignetteIntensity * t * smoothstep(0.3, 0.9, r));
        sampledColor.rgb *= clamp(vignette, 0.0, 1.0);

        if (minEdgeDist < 0.02) {
            float edgeAlpha = smoothstep(0.0, 0.02, minEdgeDist);
            float4 edgeFallback = inTexture.sample(textureSampler, in.texCoords);
            sampledColor = mix(edgeFallback, sampledColor, edgeAlpha);
        }
    } else {
        sampledColor = inTexture.sample(textureSampler, uv);
    }

    // MARK: - 2. AI Cinematic Video Bokeh Blur (if active and mask present)
    if (uniforms.hasSegmentationMask > 0 && uniforms.cinematicBlurRadius > 0.5) {
        float personAlpha = maskTexture.sample(textureSampler, uv).r; // 1.0 on person, 0.0 on background
        
        // Multi-tap Bokeh Disk Sampling for background blur
        float blurScale = (uniforms.cinematicBlurRadius / 1000.0) * (1.0 - personAlpha);
        if (blurScale > 0.0005) {
            float4 blurredColor = float4(0.0);
            const int sampleCount = 8;
            const float2 sampleOffsets[8] = {
                float2(-0.707,  0.707), float2( 0.707,  0.707),
                float2(-0.707, -0.707), float2( 0.707, -0.707),
                float2( 0.0,    1.0  ), float2( 0.0,   -1.0  ),
                float2( 1.0,    0.0  ), float2(-1.0,    0.0  )
            };
            
            for (int i = 0; i < sampleCount; ++i) {
                float2 samplePos = clamp(uv + (sampleOffsets[i] * blurScale), 0.0, 1.0);
                blurredColor += inTexture.sample(textureSampler, samplePos);
            }
            blurredColor /= float(sampleCount);
            
            // Blend sharp subject foreground with creamy blurred background
            sampledColor = mix(blurredColor, sampledColor, smoothstep(0.15, 0.85, personAlpha));
        }
    }

    // MARK: - 3. 3D Color LUT Film Emulation
    sampledColor.rgb = applyColorLUT(sampledColor.rgb, uniforms.lutPresetIndex, uniforms.lutIntensity);

    return sampledColor;
}
