#ifndef LiquidGlassShaderTypes_h
#define LiquidGlassShaderTypes_h

#include <simd/simd.h>

#define SHAPE_TYPE_NONE 0
#define SHAPE_TYPE_SQUIRCLE 1
#define SHAPE_TYPE_ELLIPSE 2
#define SHAPE_TYPE_ROUNDED_RECT 3

#define MAX_SHAPES 32

typedef struct {
    simd_float2 center;
    simd_float2 size;
    float cornerRadius;
    float rotation;
    simd_float2 scale;
    int type;
    float visibility;
    float padding[2];
} LiquidGlassShapeData;

typedef struct {
    simd_float2 size;
    simd_float2 lightDirection;
    simd_float4 glassColor;
    float time;
    float thickness;
    float refractiveIndex;
    float blur;
    float chromaticAberration;
    float lightIntensity;
    float ambientStrength;
    float saturation;
    float blend;
    float visibility;
    simd_float2 textureOffset;

} LiquidGlassUniforms;

typedef struct {
    int count;
    float padding[3];
    LiquidGlassShapeData shapes[MAX_SHAPES];
} LiquidGlassShapeUniforms;

#endif /* LiquidGlassShaderTypes_h */
