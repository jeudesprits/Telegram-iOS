#ifndef LiquidGlassShaderCommon_h
#define LiquidGlassShaderCommon_h

#ifdef __METAL_VERSION__

#include <metal_stdlib>
using namespace metal;

// MARK: - Math Utilities

inline float2x2 rotate2d(float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return float2x2(c, -s, s, c);
}

// MARK: - SDF Functions

// Rounded Rectangle
inline float sdfRRect(float2 p, float2 b, float r) {
    float2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

// Squircle (Superellipse approximation)
inline float sdfSquircle(float2 p, float2 b, float r) {
    // A simple approximation: max(abs(x), abs(y))^n ...
    // But the Flutter shader used a specific formula:
    // vec2 q = abs(p) - b + r;
    // vec2 maxQ = max(q, 0.0);
    // return min(max(q.x, q.y), 0.0) + sqrt(maxQ.x * maxQ.x + maxQ.y * maxQ.y) - r;
    // Wait, the Flutter shader `sdfSquircle` implementation was identical to `sdfRRect` but maybe they intended different curvature?
    // Let's check the Flutter code again.
    // "sdfSquircle... return min(max(q.x, q.y), 0.0) + sqrt(maxQ.x * maxQ.x + maxQ.y * maxQ.y) - r;"
    // This looks like standard rounded rect. True squircles are x^4 + y^4 = r^4.
    // Let's use the Flutter implementation for consistency.
    float2 q = abs(p) - b + r;
    float2 maxQ = max(q, 0.0);
    return min(max(q.x, q.y), 0.0) + length(maxQ) - r;
}

// Ellipse
inline float sdfEllipse(float2 p, float2 r) {
    // Approx distance to ellipse
    // k1 = length(p/r); k2 = length(p/(r*r))
    // return k1*(k1-1.0)/k2;
    
    // Safety check
    float2 r_safe = max(r, float2(1e-4));
    
    float2 invR = 1.0 / r_safe;
    float2 invR2 = invR * invR;
    
    float2 pInvR = p * invR;
    float k1 = length(pInvR);
    
    float2 pInvR2 = p * invR2;
    float k2 = length(pInvR2);
    
    return (k1 * (k1 - 1.0)) / max(k2, 1e-4);
}

// MARK: - Blending

// Polynomial Smooth Min (smin)
// Using mixing factor k
inline float smoothUnion(float d1, float d2, float k) {
    if (k <= 0.0) {
        return min(d1, d2);
    }
    float h = max(k - abs(d1 - d2), 0.0);
    return min(d1, d2) - h * h * 0.25 / k;
}

// MARK: - Rendering Functions (Ported from Flutter)

constant float3 LUMA_WEIGHTS = float3(0.299, 0.587, 0.114);

// Determine highlight color with gradual transition from colored to white based on darkness
inline float3 getHighlightColor(float3 backgroundColor, float targetBrightness) {
    float luminance = dot(backgroundColor, LUMA_WEIGHTS);
    
    // Fast saturation approximation
    float maxComponent = max(max(backgroundColor.r, backgroundColor.g), backgroundColor.b);
    
    // Combined color influence factor
    float lum = luminance * 2.5;
    float lumFactor = lum / (1.0 + lum);
    
    float sat = maxComponent * 2.5;
    float satFactor = sat / (1.0 + sat);
    
    float colorInfluence = lumFactor * satFactor;
    
    // Normalize and tint
    float3 tinted = (backgroundColor / max(luminance, 0.001)) * targetBrightness;
    
    return mix(float3(targetBrightness), tinted, colorInfluence);
}

// Calculate height/depth of the liquid surface
inline float getHeight(float sd, float thickness) {
    if (sd >= 0.0 || thickness <= 0.0) {
        return 0.0;
    }
    if (sd < -thickness) {
        return thickness;
    }
    
    float x = thickness + sd;
    return sqrt(max(0.0, thickness * thickness - x * x));
}

// Calculate lighting effects
inline float3 calculateLighting(
    float2 uv,
    float3 normal,
    float sd,
    float thickness,
    float height,
    float2 lightDirection,
    float lightIntensity,
    float ambientStrength,
    float3 backgroundColor
) {
    float normalizedHeight = thickness > 0.0 ? height / thickness : 0.0;
    float shape = clamp((1.0 - normalizedHeight) * 1.111, 0.0, 1.0);

    if (shape < 0.01) return float3(0.0);

    float thicknessFactor = clamp((thickness - 5.0) * 0.5, 0.0, 1.0);
    if (thicknessFactor < 0.01) return float3(0.0);

    // Rim lighting
    float rimWidth = 1.5;
    float k = 0.89;
    float x = sd / rimWidth;
    float rimFactor = 1.0 / (1.0 + k * x * x);

    if (rimFactor < 0.01 || lightIntensity < 0.01) return float3(0.0);

    float2 normalXY = normal.xy;
    float mainLightInfluence = max(0.0, dot(normalXY, lightDirection));
    float oppositeLightInfluence = max(0.0, dot(normalXY, -lightDirection));
    float totalInfluence = mainLightInfluence + oppositeLightInfluence * 0.8;

    float3 highlightColor = getHighlightColor(backgroundColor, 1.0);

    float3 directionalRim = (highlightColor * 0.7) * (totalInfluence * totalInfluence) * lightIntensity * 2.0;
    float3 ambientRim = (highlightColor * 0.4) * ambientStrength;

    float3 totalRimLight = (directionalRim + ambientRim) * rimFactor;

    return totalRimLight * thicknessFactor * shape;
}

// Calculate refraction with chromatic aberration
inline float4 calculateRefraction(
    float2 screenUV,
    float3 normal,
    float height,
    float thickness,
    float refractiveIndex,
    float chromaticAberration,
    float2 uSize,
    texture2d<float> backgroundTexture,
    sampler s
) {
    float baseHeight = thickness * 8.0;
    float3 incident = float3(0.0, 0.0, -1.0);
    
    float invRefractiveIndex = 1.0 / refractiveIndex;
    float2 invUSize = 1.0 / uSize;
    
    float3 baseRefract = refract(incident, normal, invRefractiveIndex);
    float baseRefractLength = (height + baseHeight) / max(0.001, abs(baseRefract.z));
    float2 baseDisplacement = baseRefract.xy * baseRefractLength;
    
    // No CA
    if (chromaticAberration < 0.001) {
        float2 refractedUV = screenUV + baseDisplacement * invUSize;
        // Clamp to avoid edge artifacts
        refractedUV = clamp(refractedUV, float2(0.001), float2(0.999));
        return backgroundTexture.sample(s, refractedUV);
    }
    
    // CA
    float dispersionStrength = chromaticAberration * 0.5;
    float2 redOffset = baseDisplacement * (1.0 + dispersionStrength);
    float2 blueOffset = baseDisplacement * (1.0 - dispersionStrength);

    float2 redUV = clamp(screenUV + redOffset * invUSize, 0.001, 0.999);
    float2 greenUV = clamp(screenUV + baseDisplacement * invUSize, 0.001, 0.999);
    float2 blueUV = clamp(screenUV + blueOffset * invUSize, 0.001, 0.999);

    float red = backgroundTexture.sample(s, redUV).r;
    float4 greenSample = backgroundTexture.sample(s, greenUV);
    float blue = backgroundTexture.sample(s, blueUV).b;

    return float4(red, greenSample.g, blue, greenSample.a);
}

inline float3 applySaturation(float3 color, float saturation) {
    float luminance = dot(color, LUMA_WEIGHTS);
    float3 saturatedColor = mix(float3(luminance), color, saturation);
    return clamp(saturatedColor, 0.0, 1.0);
}

inline float4 applyGlassColor(float4 liquidColor, float4 glassColor) {
    float4 finalColor = liquidColor;
    
    if (glassColor.a > 0.0) {
        float glassLuminance = dot(glassColor.rgb, LUMA_WEIGHTS);
        
        if (glassLuminance < 0.5) {
            float3 darkened = liquidColor.rgb * (glassColor.rgb * 2.0);
            finalColor.rgb = mix(liquidColor.rgb, darkened, glassColor.a);
        } else {
            float3 invLiquid = float3(1.0) - liquidColor.rgb;
            float3 invGlass = float3(1.0) - glassColor.rgb;
            float3 screened = float3(1.0) - (invLiquid * invGlass);
            finalColor.rgb = mix(liquidColor.rgb, screened, glassColor.a);
        }
        finalColor.a = liquidColor.a;
    }
    return finalColor;
}

// Complete Rendering Pipeline
inline float4 renderLiquidGlass(
    float2 screenUV,
    float2 uSize,
    float sd,
    float thickness,
    float refractiveIndex,
    float chromaticAberration,
    float4 glassColor,
    float2 lightDirection,
    float lightIntensity,
    float ambientStrength,
    texture2d<float> backgroundTexture,
    float3 normal,
    float foregroundAlpha,
    float saturation,
    sampler s
) {
    float height = getHeight(sd, thickness);
    
    float4 refractColor = calculateRefraction(screenUV, normal, height, thickness, refractiveIndex, chromaticAberration, uSize, backgroundTexture, s);
    
    float3 backgroundColor = refractColor.rgb;
    
    float3 lighting = calculateLighting(screenUV, normal, sd, thickness, height, lightDirection, lightIntensity, ambientStrength, backgroundColor);
    
    float4 finalColor = applyGlassColor(refractColor, glassColor);
    
    finalColor.rgb += lighting;
    finalColor.rgb = applySaturation(finalColor.rgb, saturation);
    
    // Mix with background based on alpha (foregroundAlpha is our shape mask)
    // Sample original background for blending at the edges
    float4 bgSample = backgroundTexture.sample(s, screenUV);
    
    // Mix background and glass effect based on shape alpha
    // This provides smooth anti-aliased edges by transitioning to the original background
    return mix(bgSample, finalColor, foregroundAlpha);
}

#endif // __METAL_VERSION__

#endif /* LiquidGlassShaderCommon_h */
