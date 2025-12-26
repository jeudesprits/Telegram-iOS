#include <metal_stdlib>
#include "LiquidGlassShaderTypes.h"
#include "LiquidGlassShaderCommon.h"

using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut liquid_vertex(uint vertexID [[vertex_id]]) {

    const float2 vertices[] = {
        float2(-1, -1),
        float2( 3, -1),
        float2(-1,  3)
    };
    
    float2 pos = vertices[vertexID];
    
    VertexOut out;
    out.position = float4(pos, 0, 1);
    out.uv = (pos + 1.0) * 0.5;
    out.uv.y = 1.0 - out.uv.y;
    return out;
}

// MARK: - SDF Scene

float getShapeSDF(float2 p, LiquidGlassShapeData shape) {
    float2 localP = p - shape.center;

    if (abs(shape.rotation) > 0.001) {
        localP = rotate2d(-shape.rotation) * localP;
    }

    float2 scale = shape.scale;
    if (scale.x == 0 || scale.y == 0) scale = float2(1.0);
    
    float2 pPrime = localP / scale;
    float2 halfSize = shape.size * 0.5;
    float r = shape.cornerRadius;
    
    float d = 1e9;
    
    if (shape.type == SHAPE_TYPE_SQUIRCLE) {
        d = sdfSquircle(pPrime, halfSize, r);
    } else if (shape.type == SHAPE_TYPE_ELLIPSE) {
        d = sdfEllipse(pPrime, halfSize);
    } else if (shape.type == SHAPE_TYPE_ROUNDED_RECT) {
        d = sdfRRect(pPrime, halfSize, r);
    }

    return d * min(scale.x, scale.y);
}

float sceneSDF(float2 p, constant LiquidGlassShapeUniforms& shapeUniforms, float blend) {
    float minD = 1e9;
    
    for (int i = 0; i < shapeUniforms.count; i++) {
        LiquidGlassShapeData shape = shapeUniforms.shapes[i];

        if (shape.visibility < 0.01) continue;
        
        float d = getShapeSDF(p, shape);
        
        if (i == 0) {
            minD = d;
        } else {
            minD = smoothUnion(minD, d, blend);
        }
    }
    
    return minD;
}

// MARK: - Fragment Shader

fragment float4 liquid_fragment(VertexOut in [[stage_in]],
                                constant LiquidGlassUniforms& uniforms [[buffer(0)]],
                                constant LiquidGlassShapeUniforms& shapes [[buffer(1)]],
                                texture2d<float> textureOriginal [[texture(0)]],
                                texture2d<float> textureBlurred [[texture(1)]]) {

    float2 p = in.position.xy;

    float d = sceneSDF(p, shapes, uniforms.blend);

    float alpha = 1.0 - smoothstep(-1.5, 0.5, d);
    
    if (alpha < 0.01) {
        discard_fragment();
        return float4(0);
    }

    float eps = 1.0;
    float d_x = sceneSDF(p + float2(eps, 0), shapes, uniforms.blend) - sceneSDF(p - float2(eps, 0), shapes, uniforms.blend);
    float d_y = sceneSDF(p + float2(0, eps), shapes, uniforms.blend) - sceneSDF(p - float2(0, eps), shapes, uniforms.blend);
    
    float2 grad = normalize(float2(d_x, d_y));

    float thickness = uniforms.thickness;
    float distInside = max(-d, 0.0);
    float height = distInside;
    
    if (distInside < thickness) {
        float x = thickness - distInside;
        height = sqrt(max(0.0, thickness*thickness - x*x));
    } else {
        height = thickness;
    }

    float slope = 0.0;
    if (height > 0.001 && distInside < thickness) {
        slope = (thickness - distInside) / height;
    }
    
    float3 normal = normalize(float3(-grad * slope, 1.0));

    constexpr sampler s(filter::linear, address::clamp_to_edge);

    texture2d<float> bgTex = (uniforms.blur > 0.1) ? textureBlurred : textureOriginal;

    float2 correctedUV;
    
    if (uniforms.blur > 0.1) {
        correctedUV = in.uv;
    } else {
        float2 texSize = float2(bgTex.get_width(), bgTex.get_height());
        float2 viewPixel = in.uv * uniforms.size;
        float2 texPixel = viewPixel + uniforms.textureOffset;
        correctedUV = texPixel / texSize;
    }

    float4 finalColor = renderLiquidGlass(
        correctedUV,
        uniforms.size,
        d,
        uniforms.thickness,
        uniforms.refractiveIndex,
        uniforms.chromaticAberration,
        uniforms.glassColor,
        normalize(uniforms.lightDirection),
        uniforms.lightIntensity,
        uniforms.ambientStrength,
        bgTex,
        normal,
        alpha,
        uniforms.saturation,
        s
    );

    return finalColor * uniforms.visibility;
}
