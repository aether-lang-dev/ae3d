#version 450
// fxaa: written by ae3d.gpu from its tree.

layout(std140, set = 0, binding = 0) uniform Params {
    vec2 texelSize;
    float edgeThreshold;
    float edgeThresholdMin;
    float subpixelQuality;
};
layout(set = 0, binding = 1) uniform sampler2D screenTexture;

layout(location = 0) in vec2 TexCoords;
layout(location = 0) out vec4 FragColor;

void main() {
    vec3 colorCenter = texture(screenTexture, TexCoords).rgb;
    vec3 lumaCoeff = vec3(0.299, 0.587, 0.114);
    vec3 colorN = texture(screenTexture, TexCoords + vec2(0.0, -1.0) * texelSize).rgb;
    vec3 colorS = texture(screenTexture, TexCoords + vec2(0.0, 1.0) * texelSize).rgb;
    vec3 colorE = texture(screenTexture, TexCoords + vec2(1.0, 0.0) * texelSize).rgb;
    vec3 colorW = texture(screenTexture, TexCoords + vec2(-1.0, 0.0) * texelSize).rgb;
    float lumaCenter = dot(colorCenter, lumaCoeff);
    float lumaN = dot(colorN, lumaCoeff);
    float lumaS = dot(colorS, lumaCoeff);
    float lumaE = dot(colorE, lumaCoeff);
    float lumaW = dot(colorW, lumaCoeff);
    float lumaMin = min(lumaCenter, min(min(lumaN, lumaS), min(lumaE, lumaW)));
    float lumaMax = max(lumaCenter, max(max(lumaN, lumaS), max(lumaE, lumaW)));
    float lumaRange = lumaMax - lumaMin;
    if (lumaRange < max(edgeThresholdMin, lumaMax * edgeThreshold)) {
        FragColor = vec4(colorCenter, 1.0);
        return;
    }
    float lumaDown = lumaN + lumaS;
    float lumaAcross = lumaE + lumaW;
    float lumaTotal = lumaDown + lumaAcross;
    float lumaAvg = lumaTotal * 0.25;
    float subpixelOffset = abs(lumaAvg - lumaCenter) / lumaRange;
    subpixelOffset = clamp(subpixelOffset, 0.0, 1.0);
    subpixelOffset = smoothstep(0.0, 1.0, subpixelOffset);
    subpixelOffset = subpixelOffset * subpixelOffset * subpixelQuality;
    float edgeHorizontal = abs(-2.0 * lumaW + lumaCenter) + abs(-2.0 * lumaCenter + lumaE) * 2.0 + abs(-2.0 * lumaE + lumaCenter);
    float edgeVertical = abs(-2.0 * lumaN + lumaCenter) + abs(-2.0 * lumaCenter + lumaS) * 2.0 + abs(-2.0 * lumaS + lumaCenter);
    bool isHorizontal = edgeHorizontal >= edgeVertical;
    float luma1 = isHorizontal ? lumaS : lumaE;
    float luma2 = isHorizontal ? lumaN : lumaW;
    float gradient1 = luma1 - lumaCenter;
    float gradient2 = luma2 - lumaCenter;
    bool is1Steepest = abs(gradient1) >= abs(gradient2);
    float lengthSign = is1Steepest ? sign(gradient1) : sign(gradient2);
    float subpixelBlend = subpixelOffset * lengthSign;
    vec2 offset = isHorizontal ? vec2(0.0, subpixelBlend * texelSize.y) : vec2(subpixelBlend * texelSize.x, 0.0);
    vec3 colorFinal = texture(screenTexture, TexCoords + offset).rgb;
    FragColor = vec4(colorFinal, 1.0);
}
