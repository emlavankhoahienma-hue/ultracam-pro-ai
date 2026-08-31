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
    float zoomFactor;           // Range: 0.5 to 5.0
    float distortionStrength;   // Distortion curvature factor (default: ~0.45)
    float k1;                   // Primary barrel coefficient (default: 0.35)
    float k2;                   // Secondary barrel coefficient (default: 0.15)
    float aspectRatio;          // Frame width / height ratio
    float edgeFeathering;       // Border transition smoothing (0.0 to 1.0)
    float vignetteIntensity;    // Corner vignette correction (0.0 to 1.0)
    float chromaticAberration;  // RGB channel dispersion correction
    int lutPresetIndex;         // 0: Normal, 1: Fuji, 2: Portra, 3: Leica B&W, 4: CineStill, 5: TealOrange
    float lutIntensity;         // 0.0 to 1.0
    float cinematicBlurRadius;  // 0.0 (off) to 12.0
    int hasSegmentationMask;    // 1 if mask is bound, 0 otherwise
};

// MARK: - Color Grading 3D Film LUT Functions
inline float3 applyColorLUT(float3 color, int presetIndex, float intensity) {
    if (presetIndex == 0 || intensity <= 0.001) {
        return color;
    }
    
    float3 graded = color;
    
    // Preset 1: Fuji Classic Chrome
    if (presetIndex == 1) {
        graded.r = pow(color.r, 1.06) * 0.97 + 0.02;
        graded.g = pow(color.g, 0.98) * 1.01;
        graded.b = pow(color.b, 1.04) * 0.95;
        float luma = dot(graded, float3(0.299, 0.587, 0.114));
        graded = mix(float3(luma), graded, 0.88);
    }
    // Preset 2: Kodak Portra 400
    else if (presetIndex == 2) {
        graded.r = color.r * 1.07 + 0.02;
        graded.g = color.g * 1.01 + 0.01;
        graded.b = color.b * 0.93;
        graded = pow(clamp(graded, 0.0, 1.0), float3(0.96, 0.99, 1.04));
    }
    // Preset 3: Leica Monochrome
    else if (presetIndex == 3) {
        float luma = dot(color, float3(0.299, 0.587, 0.114));
        float contrast = (luma - 0.5) * 1.25 + 0.5;
        graded = float3(clamp(contrast, 0.0, 1.0));
    }
    // Preset 4: Cinestill 800T
    else if (presetIndex == 4) {
        graded.r = color.r * 1.12 + (pow(color.r, 2.2) * 0.08);
        graded.g = color.g * 0.98;
        graded.b = color.b * 1.10 + 0.02;
    }
    // Preset 5: Teal & Orange
    else if (presetIndex == 5) {
        float luma = dot(color, float3(0.299, 0.587, 0.114));
        float3 shadows = float3(0.0, 0.65, 0.85);
        float3 highlights = float3(1.05, 0.70, 0.20);
        graded = mix(shadows * luma * 1.3, highlights, smoothstep(0.25, 0.85, luma));
        graded = mix(color, graded, 0.65);
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

// MARK: - Fragment Shader: Ultra-Wide 0.5x Fisheye Barrel + Cinematic Smooth Bokeh + 3D LUT
fragment float4 ultraWideFragmentShader(MetalVertexOut in [[stage_in]],
                                        texture2d<float, access::sample> inTexture [[texture(0)]],
                                        texture2d<float, access::sample> maskTexture [[texture(1)]],
                                        constant DistortionUniforms &uniforms [[buffer(0)]]) {
    constexpr sampler linearSampler(coord::normalized,
                                    address::clamp_to_edge,
                                    filter::linear);

    float zoom = uniforms.zoomFactor;
    float2 uv = in.texCoords;
    float4 sampledColor;

    // MARK: - 1. True 0.5x Ultra-Wide Fisheye / Barrel Expansion Algorithm
    if (zoom < 1.0) {
        float aspect = uniforms.aspectRatio > 0.0 ? uniforms.aspectRatio : (9.0 / 16.0);
        float2 p = uv - float2(0.5, 0.5);
        p.x *= aspect;

        float r = length(p);
        float t = clamp((1.0 - zoom) / 0.5, 0.0, 1.0); // 0.0 at 1.0x, 1.0 at 0.5x
        
        // Spherical barrel projection model
        float k = (0.55 * uniforms.distortionStrength + 0.15) * t;
        float distortionFactor = 1.0 + (k * r * r) + (0.5 * k * r * r * r * r);
        
        // Transform coordinates with wide-angle perspective bulge
        float2 warpedP = p * distortionFactor;
        warpedP.x /= aspect;
        
        float2 sampleUV = warpedP + float2(0.5, 0.5);

        // Peripheral chromatic aberration simulation
        float caShift = 0.003 * t * r;
        float2 redUV   = sampleUV + (warpedP * caShift);
        float2 blueUV  = sampleUV - (warpedP * caShift);

        float4 cR = inTexture.sample(linearSampler, clamp(redUV, 0.0, 1.0));
        float4 cG = inTexture.sample(linearSampler, clamp(sampleUV, 0.0, 1.0));
        float4 cB = inTexture.sample(linearSampler, clamp(blueUV, 0.0, 1.0));
        sampledColor = float4(cR.r, cG.g, cB.b, 1.0);

        // Vignette falloff
        float vignette = 1.0 - (uniforms.vignetteIntensity * t * smoothstep(0.35, 0.85, r));
        sampledColor.rgb *= clamp(vignette, 0.0, 1.0);
    } else {
        sampledColor = inTexture.sample(linearSampler, uv);
    }

    // MARK: - 2. AI Cinematic Video Bokeh (16-Tap Poisson Disk with Smooth Subject Falloff)
    if (uniforms.hasSegmentationMask > 0 && uniforms.cinematicBlurRadius > 0.5) {
        float personAlpha = maskTexture.sample(linearSampler, uv).r;
        
        // Only apply bokeh blur if person is detected and on background pixels
        if (personAlpha < 0.95) {
            float blurAmount = (uniforms.cinematicBlurRadius / 250.0) * (1.0 - personAlpha);
            
            if (blurAmount > 0.0005) {
                // 16-point Poisson Disk Distribution for artifact-free creamy bokeh
                const float2 poissonDisk[16] = {
                    float2(-0.326, -0.406), float2(-0.840, -0.074),
                    float2(-0.696,  0.457), float2(-0.203,  0.621),
                    float2( 0.962, -0.195), float2( 0.473, -0.480),
                    float2( 0.519,  0.767), float2( 0.185, -0.893),
                    float2( 0.507,  0.064), float2( 0.896,  0.412),
                    float2(-0.322, -0.933), float2(-0.792, -0.598),
                    float2(-0.165,  0.134), float2( 0.395,  0.375),
                    float2(-0.463,  0.865), float2( 0.028,  0.038)
                };

                float4 blurredSum = float4(0.0);
                float totalWeight = 0.0;

                for (int i = 0; i < 16; ++i) {
                    float2 offset = poissonDisk[i] * blurAmount;
                    float2 samplePos = clamp(uv + offset, 0.0, 1.0);
                    float samplePerson = maskTexture.sample(linearSampler, samplePos).r;
                    
                    // Weight samples to prevent foreground subject colors from bleeding into background
                    float weight = 1.0 - (samplePerson * 0.85);
                    blurredSum += inTexture.sample(linearSampler, samplePos) * weight;
                    totalWeight += weight;
                }

                if (totalWeight > 0.001) {
                    float4 backgroundBokeh = blurredSum / totalWeight;
                    sampledColor = mix(backgroundBokeh, sampledColor, smoothstep(0.05, 0.80, personAlpha));
                }
            }
        }
    }

    // MARK: - 3. 3D Color LUT Film Emulation
    sampledColor.rgb = applyColorLUT(sampledColor.rgb, uniforms.lutPresetIndex, uniforms.lutIntensity);

    return sampledColor;
}
