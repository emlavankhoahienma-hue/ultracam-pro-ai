#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

struct VertexIn {
    vector_float2 position;
    vector_float2 texCoords;
};

struct VertexOut {
    vector_float4 position;
    vector_float2 texCoords;
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
};

#endif /* ShaderTypes_h */
