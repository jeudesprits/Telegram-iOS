#ifndef LiquidGlassShaderTypes_h
#define LiquidGlassShaderTypes_h

#include <simd/simd.h>

// Shape types
#define SHAPE_TYPE_NONE 0
#define SHAPE_TYPE_SQUIRCLE 1
#define SHAPE_TYPE_ELLIPSE 2
#define SHAPE_TYPE_ROUNDED_RECT 3

// Max shapes for batching
#define MAX_SHAPES 32

typedef struct {
    // 0
    simd_float2 center;
    // 8
    simd_float2 size;
    // 16
    float cornerRadius;
    // 20
    float rotation; // Radians
    // 24
    simd_float2 scale; // For squash & stretch
    // 32
    int type;
    // 36
    float visibility; // 0.0 - 1.0 (for cross-fade animations)
    // 40
    float padding[2]; // Pad to 48 bytes (or 16-byte multiple if needed, let's check)
    // sizeof = 48 (multiple of 16)
} LiquidGlassShapeData;

typedef struct {
    // 0
    simd_float2 size; // Viewport size
    // 8
    simd_float2 lightDirection;
    // 16
    simd_float4 glassColor;
    // 32
    float time;
    // 36
    float thickness;
    // 40
    float refractiveIndex;
    // 44
    float blur;
    // 48
    float chromaticAberration;
    // 52
    float lightIntensity;
    // 56
    float ambientStrength;
    // 60
    float saturation;
    // 64
    float blend; // SDF Blend amount
    // 68
    float visibility; // Global visibility
    // 72
    simd_float2 textureOffset; // Subpixel offset for capture correction
    // 80
} LiquidGlassUniforms;

typedef struct {
    int count;
    float padding[3]; // Align to 16 bytes
    LiquidGlassShapeData shapes[MAX_SHAPES];
} LiquidGlassShapeUniforms;

#endif /* LiquidGlassShaderTypes_h */
