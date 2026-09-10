#include <metal_stdlib>
using namespace metal;
struct VertexOut { float4 position [[position]]; float2 uv; };
struct Params { float progress, perspective, blur, shade, style, width, height, reducedMotion; };
vertex VertexOut foldVertex(uint id [[vertex_id]]) {
    const float2 positions[] = {float2(-1,-1),float2(3,-1),float2(-1,3)};
    VertexOut out;
    out.position = float4(positions[id],0,1);
    out.uv = float2((positions[id].x+1)*0.5, (1-positions[id].y)*0.5);
    return out;
}
fragment float4 foldFragment(VertexOut in [[stage_in]], texture2d<float> desktop [[texture(0)]], constant Params &p [[buffer(0)]]) {
    constexpr sampler linearSampler(coord::normalized, address::clamp_to_edge, filter::linear, mip_filter::linear);
    float progress = clamp(p.progress,0.0f,1.0f);
    float2 uv = in.uv;
    // The hinge is the bottom edge. Inverse projection always samples the desktop;
    // there is no shrinking quadrilateral, transparent gutter, or black background.
    float outer = 1.0f - uv.y;
    float bend = pow(progress,0.80f) * p.perspective * (1.0f - p.reducedMotion);
    uv.x = 0.5f + (uv.x-0.5f)/(1.0f+0.65f*bend*outer*outer);
    uv.y = 1.0f-pow(max(0.0f,1.0f-uv.y),1.0f+1.10f*bend);
    // Core Image writes Metal textures bottom-up; the drawable is top-down.
    uv.y = 1.0f - uv.y;
    float gradient = pow(outer,0.85f);
    float styleBlur = p.style > 1.5f ? 1.4f : 1.0f;
    float radius = 190.0f * p.blur * pow(progress,0.85f) * gradient * styleBlur * p.width/1600.0f;
    float lod = max(0.0f,log2(max(1.0f,radius*0.45f)));
    float2 d = float2(radius/max(p.width,1.0f),radius/max(p.height,1.0f))*0.55f;
    float4 color = desktop.sample(linearSampler,uv,level(lod))*0.25f;
    color += (desktop.sample(linearSampler,uv+float2(d.x,0),level(lod)) + desktop.sample(linearSampler,uv-float2(d.x,0),level(lod))
            + desktop.sample(linearSampler,uv+float2(0,d.y),level(lod)) + desktop.sample(linearSampler,uv-float2(0,d.y),level(lod)))*0.125f;
    color += (desktop.sample(linearSampler,uv+d,level(lod)) + desktop.sample(linearSampler,uv-d,level(lod))
            + desktop.sample(linearSampler,uv+float2(d.x,-d.y),level(lod)) + desktop.sample(linearSampler,uv+float2(-d.x,d.y),level(lod)))*0.0625f;
    // Soft directional shade only. No fixed black border or global brightness subtraction.
    float shade = p.shade * progress * gradient * (p.style > 0.5f && p.style < 1.5f ? 0.85f : 0.60f);
    color.rgb *= 1.0f - shade;
    if (p.style > 1.5f) color.rgb = mix(color.rgb,float3(dot(color.rgb,float3(0.2126,0.7152,0.0722))),0.12f*progress*gradient);
    return float4(color.rgb,1);
}
