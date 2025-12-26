#include <metal_stdlib>
#include "LiquidGlassShaderTypes.h"
#include "LiquidGlassShaderCommon.h"

using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// MARK: - Vertex Shader

vertex VertexOut liquid_vertex(uint vertexID [[vertex_id]]) {
    // Standard full-screen quad triangle strip
    const float2 vertices[] = {
        float2(-1, -1),
        float2( 3, -1),
        float2(-1,  3)
    };
    
    float2 pos = vertices[vertexID];
    
    VertexOut out;
    out.position = float4(pos, 0, 1);
    out.uv = (pos + 1.0) * 0.5;
    out.uv.y = 1.0 - out.uv.y; // Flip Y for Metal texture coordinates
    return out;
}

// MARK: - SDF Scene

float getShapeSDF(float2 p, LiquidGlassShapeData shape) {
    // Transform point to local shape space
    float2 localP = p - shape.center;
    
    // Rotate
    if (abs(shape.rotation) > 0.001) {
        localP = rotate2d(-shape.rotation) * localP;
    }
    
    // Scale (Squash & Stretch)
    // Note: SDFs under non-uniform scaling are tricky.
    // Exact distance requires solving equations.
    // We use approximation: p' = p / scale; dist = d(p') * min(scale)
    float2 scale = shape.scale;
    if (scale.x == 0 || scale.y == 0) scale = float2(1.0); // Safety
    
    // We want to draw the shape defined by `size`.
    // If we simply divide P by scale, the shape size effectively changes.
    // If shape.size is the *target* size, we calculate SDF for that size.
    // But LiquidStretch applies transform to the VIEW.
    // If we are in LiquidGlassGroupView, the view transform is handled by modifying shape data?
    // Let's assume `shape.size` is the base size, and `scale` is applied on top.
    
    // Correct way for non-uniform scale SDF approx:
    // float2 pPrime = localP / scale;
    // float d = sdf(pPrime, size/2, radius) * min(scale.x, scale.y);
    
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
    
    // Correction for scaling
    // Using min scale is a conservative bound (safe for raymarching, okay for 2D SDF rendering)
    return d * min(scale.x, scale.y);
}

float sceneSDF(float2 p, constant LiquidGlassShapeUniforms& shapeUniforms, float blend) {
    float minD = 1e9;
    
    for (int i = 0; i < shapeUniforms.count; i++) {
        LiquidGlassShapeData shape = shapeUniforms.shapes[i];
        
        // Skip invisible shapes? Or handle visibility smoothly?
        // Plan said: "Multiplier for visibility in render pass".
        // But if we hide it in SDF, it will disappear abruptly or merge weirdly.
        // Better to include it in SDF but maybe modulate later?
        // Wait, if visibility is 0, it shouldn't affect the shape of others.
        // We can increase distance if visibility is low?
        // Or smoothUnion with 0 influence?
        
        // Simple approach: if visibility < 0.01, skip.
        if (shape.visibility < 0.01) continue;
        
        float d = getShapeSDF(p, shape);
        
        // Modulate d based on visibility?
        // If vis = 0.5, we want the shape to be "smaller" or "fading"?
        // Flutter impl changes opacity at the end.
        // Let's keep SDF strict based on geometry.
        
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
    
    // Screen coordinates (pixels)
    float2 p = in.position.xy;
    
    // Calculate SDF
    float d = sceneSDF(p, shapes, uniforms.blend);
    
    // Calculate alpha (smooth edge)
    // 0 = edge, -thickness = inside
    float alpha = 1.0 - smoothstep(-1.5, 0.5, d); // 2px anti-aliasing
    
    if (alpha < 0.01) {
        discard_fragment();
        return float4(0);
    }
    
    // Normal calculation via finite differences
    float eps = 1.0;
    float d_x = sceneSDF(p + float2(eps, 0), shapes, uniforms.blend) - sceneSDF(p - float2(eps, 0), shapes, uniforms.blend);
    float d_y = sceneSDF(p + float2(0, eps), shapes, uniforms.blend) - sceneSDF(p - float2(0, eps), shapes, uniforms.blend);
    
    float2 grad = normalize(float2(d_x, d_y));
    
    // Approximate height based on SDF
    float thickness = uniforms.thickness;
    float distInside = max(-d, 0.0);
    float height = distInside;
    
    if (distInside < thickness) {
        float x = thickness - distInside;
        height = sqrt(max(0.0, thickness*thickness - x*x));
    } else {
        height = thickness;
    }
    
    // Normal Z
    float slope = 0.0;
    if (height > 0.001 && distInside < thickness) {
        slope = (thickness - distInside) / height;
    }
    
    float3 normal = normalize(float3(-grad * slope, 1.0));
    
    // Sampler
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    
    // Select texture (blurred or original based on config)
    // In our Swift code: Index 1 is blurred if blur > 0.1, else it might be copy of Index 0.
    // If we want chromatic aberration, we need "Sharp" texture?
    // Usually CA samples from Sharp or Blurred depending on style.
    // Flutter implementation passes `uBackgroundTexture` which is the one behind.
    // And `uBlurredTexture` for some effects?
    // Actually, `renderLiquidGlass` takes `backgroundTexture`.
    // If we want the glass to look frosted, we pass `textureBlurred`.
    
    texture2d<float> bgTex = (uniforms.blur > 0.1) ? textureBlurred : textureOriginal;
    
    // UV Calculation
    float2 correctedUV;
    
    if (uniforms.blur > 0.1) {
        // For blurred (downsampled) textures, subpixel precision is irrelevant
        // and pixel-coordinate mapping would break due to resolution mismatch.
        correctedUV = in.uv;
    } else {
        // For sharp (native) textures, apply subpixel offset correction
        float2 texSize = float2(bgTex.get_width(), bgTex.get_height());
        float2 viewPixel = in.uv * uniforms.size;
        float2 texPixel = viewPixel + uniforms.textureOffset;
        correctedUV = texPixel / texSize;
    }
    
    // Render using shared pipeline
    float4 finalColor = renderLiquidGlass(
        correctedUV, // Screen UV (Corrected)
        uniforms.size,
        d,
        uniforms.thickness,
        uniforms.refractiveIndex,
        uniforms.chromaticAberration,
        uniforms.glassColor,
        normalize(uniforms.lightDirection), // Ensure normalized
        uniforms.lightIntensity,
        uniforms.ambientStrength,
        bgTex,
        normal,
        alpha,
        uniforms.saturation,
        s
    );
    
    // Apply global visibility
    return finalColor * uniforms.visibility;
}
