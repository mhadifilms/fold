#include <metal_stdlib>
using namespace metal;
struct VertexOut { float4 position [[position]]; float2 uv; };
struct Params { float progress, width, height, reducedMotion; };

// Prefilter each level with a Gaussian instead of box-filtered mipmaps. Nine
// bilinear reads implement a separable five-tap kernel without distant copies.
kernel void foldDownsample(texture2d<float, access::sample> source [[texture(0)]],
                           texture2d<float, access::write> target [[texture(1)]],
                           uint2 xy [[thread_position_in_grid]]) {
    if (xy.x >= target.get_width() || xy.y >= target.get_height()) return;
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 uv = (float2(xy)+0.5f)/float2(target.get_width(),target.get_height());
    float2 texel = 1.0f/float2(source.get_width(),source.get_height());
    const float offsets[3] = {-1.2f,0.0f,1.2f};
    const float weights[3] = {0.3125f,0.375f,0.3125f};
    float4 color = 0;
    for (int y=0;y<3;y++) for (int x=0;x<3;x++)
        color += source.sample(s,uv+float2(offsets[x],offsets[y])*texel)*weights[x]*weights[y];
    target.write(color,xy);
}
vertex VertexOut foldVertex(uint id [[vertex_id]]) {
    const float2 positions[] = {float2(-1,-1),float2(3,-1),float2(-1,3)};
    VertexOut out;
    out.position = float4(positions[id],0,1);
    out.uv = float2((positions[id].x+1)*0.5, (1-positions[id].y)*0.5);
    return out;
}
fragment float4 foldFragment(VertexOut in [[stage_in]], texture2d<float> desktop [[texture(0)]], constant Params &p [[buffer(0)]]) {
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear, mip_filter::linear);
    float progress = clamp(p.progress,0.0f,1.0f);
    float outer = 1.0f-in.uv.y;
    float bend = pow(progress,0.85f)*0.78f*(1.0f-p.reducedMotion);
    // A continuous projective mapping has a finite slope at both edges; a power
    // warp flattened the bottom rows into a visible horizontal compression band.
    float2 uv;
    uv.x = 0.5f+(in.uv.x-0.5f)/(1.0f+0.46f*bend*outer*outer);
    // Core Image textures are bottom-up. Keep both endpoints filled and pinned.
    uv.y = outer/(1.0f+1.15f*bend*(1.0f-outer));
    float gradient = pow(outer,1.15f);
    float sigma = 84.0f*pow(progress,0.85f)*gradient*p.width/1600.0f;
    // Interpolate variance between adjacent prefiltered levels for a continuous
    // focus field. At zero progress the original, unfiltered image is exact.
    float lod = 0.5f*log2(1.0f+3.0f*sigma*sigma/1.25f);
    float lower = floor(lod);
    float variance0 = (exp2(2.0f*lower)-1.0f)*1.25f/3.0f;
    float variance1 = (exp2(2.0f*(lower+1.0f))-1.0f)*1.25f/3.0f;
    float fraction = clamp((sigma*sigma-variance0)/max(variance1-variance0,0.001f),0.0f,1.0f);
    float4 color = desktop.sample(s,uv,level(lower+fraction));
    color.rgb *= 1.0f-0.10f*progress*gradient;
    return float4(color.rgb,1);
}
