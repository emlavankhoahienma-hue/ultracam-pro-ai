#include <metal_stdlib>
#include <simd/simd.h>
#import "ShaderTypes.h"

using namespace metal;

struct MetalVertexOut {
    float4 position [[position]];
    float2 texCoords;
};

// MARK: - Vertex Shader
vertex MetalVertexOut ultraWideVertexShader(uint vertexID [[vertex_id]],
                                            constant VertexIn *vertices [[buffer(0)]]) {
    MetalVertexOut out;
    out.position = float4(vertices[vertexID].position, 0.0, 1.0);
    out.texCoords = vertices[vertexID].texCoords;
    return out;
}

// MARK: - Fragment Shader: 0.5x Barrel Distortion & Ultra-Wide Emulation
fragment float4 ultraWideFragmentShader(MetalVertexOut in [[stage_in]],
                                        texture2d<float, access::sample> inTexture [[texture(0)]],
                                        constant DistortionUniforms &uniforms [[buffer(0)]]) {
    // Linear sampler with clamp to edge for edge anti-aliasing
    constexpr sampler textureSampler(coord::normalized,
                                     address::clamp_to_edge,
                                     filter::linear,
                                     mip_filter::linear);

    float zoom = uniforms.zoomFactor;
    
    // Pass-through if zoom factor is 1.0 or greater (Hardware optical zoom handles >= 1.0)
    if (zoom >= 1.0) {
        return inTexture.sample(textureSampler, in.texCoords);
    }

    // Normalized UV coordinate centered at (0.0, 0.0)
    float2 uv = in.texCoords;
    float aspect = uniforms.aspectRatio > 0.0 ? uniforms.aspectRatio : (16.0 / 9.0);
    
    // Normalize coordinates around optical center with aspect ratio compensation
    float2 centered = (uv - float2(0.5, 0.5));
    centered.x *= aspect;

    // Radius from optical center
    float r = length(centered);

    // Compute barrel distortion blend factor based on zoom (0.5x -> max effect, 1.0x -> zero effect)
    float t = clamp((1.0 - zoom) / 0.5, 0.0, 1.0); // 0.0 at zoom 1.0, 1.0 at zoom 0.5
    float k1 = uniforms.k1 * t;
    float k2 = uniforms.k2 * t;

    // Polynomial radial expansion model for ultra-wide barrel projection
    // r_distorted = r * (1 + k1 * r^2 + k2 * r^4)
    float r2 = r * r;
    float r4 = r2 * r2;
    float distortionScale = 1.0 + k1 * r2 + k2 * r4;

    // Scale coordinates to simulate wide-angle field of view (FOV) expansion
    float fovScale = mix(1.0, zoom, t * 0.95);
    float2 distortedCentered = centered * distortionScale * fovScale;

    // Unscale aspect ratio and translate back to [0.0, 1.0] UV texture space
    distortedCentered.x /= aspect;
    float2 sampleUV = distortedCentered + float2(0.5, 0.5);

    // Border bounds check for edge anti-aliasing and feathering
    float edgeDistX = min(sampleUV.x, 1.0 - sampleUV.x);
    float edgeDistY = min(sampleUV.y, 1.0 - sampleUV.y);
    float minEdgeDist = min(edgeDistX, edgeDistY);
    
    // Chromatic Aberration simulation at periphery (lens dispersion)
    float caShift = 0.0025 * t * (r * 1.5);
    float2 redUV   = sampleUV + (distortedCentered * caShift);
    float2 blueUV  = sampleUV - (distortedCentered * caShift);
    float2 greenUV = sampleUV;

    float4 colorR = inTexture.sample(textureSampler, clamp(redUV, 0.0, 1.0));
    float4 colorG = inTexture.sample(textureSampler, clamp(greenUV, 0.0, 1.0));
    float4 colorB = inTexture.sample(textureSampler, clamp(blueUV, 0.0, 1.0));

    float4 finalColor = float4(colorR.r, colorG.g, colorB.b, 1.0);

    // Vignette simulation to match physical ultra-wide lens optical falloff
    float vignette = 1.0 - (uniforms.vignetteIntensity * t * smoothstep(0.3, 0.9, r));
    finalColor.rgb *= clamp(vignette, 0.0, 1.0);

    // Edge anti-aliasing feathering to prevent pixel jaggedness at severe curvature
    if (minEdgeDist < 0.02) {
        float edgeAlpha = smoothstep(0.0, 0.02, minEdgeDist);
        float4 edgeFallback = inTexture.sample(textureSampler, in.texCoords);
        finalColor = mix(edgeFallback, finalColor, edgeAlpha);
    }

    return finalColor;
}
