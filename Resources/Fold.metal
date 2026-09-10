#include <metal_stdlib>
using namespace metal;
struct VertexOut { float4 position [[position]]; float2 uv; };
struct Params { float progress, width, height, reducedMotion; };

// A wider, separable Gaussian keeps each level smooth between texels. Narrow
// mip kernels produced faint bands when the focus field crossed coarse levels.
kernel void foldDownsample(texture2d<float, access::sample> source [[texture(0)]],
                           texture2d<float, access::write> target [[texture(1)]],
                           constant uint &horizontal [[buffer(0)]],
                           uint2 xy [[thread_position_in_grid]]) {
    if (xy.x >= target.get_width() || xy.y >= target.get_height()) return;
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 uv = (float2(xy)+0.5f)/float2(target.get_width(),target.get_height());
    float2 axis = horizontal ? float2(1.0f/source.get_width(),0) : float2(0,1.0f/source.get_height());
    const float offsets[3] = {1.4584295f,3.4039848f,5.3518058f};
    const float weights[3] = {0.2393373f,0.1394403f,0.0527110f};
    float4 color = source.sample(s,uv)*0.1370228f;
    for (int i=0;i<3;i++)
        color += (source.sample(s,uv+offsets[i]*axis)+source.sample(s,uv-offsets[i]*axis))*weights[i];
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
    // The physical lid already supplies perspective. Keep every desktop
    // coordinate fixed; only focus and illumination change while it folds.
    // Core Image textures are bottom-up.
    float2 uv = float2(in.uv.x,outer);
    float gradient = pow(outer,1.85f);
    float sigma = 96.0f*pow(progress,0.90f)*gradient*p.width/1600.0f;
    // Interpolate variance between adjacent prefiltered levels for a continuous
    // focus field. At zero progress the original, unfiltered image is exact.
    const float kernelVariance = 7.4790772f;
    float lod = 0.5f*log2(1.0f+3.0f*sigma*sigma/kernelVariance);
    float lower = floor(lod);
    float variance0 = (exp2(2.0f*lower)-1.0f)*kernelVariance/3.0f;
    float variance1 = (exp2(2.0f*(lower+1.0f))-1.0f)*kernelVariance/3.0f;
    float fraction = clamp((sigma*sigma-variance0)/max(variance1-variance0,0.001f),0.0f,1.0f);
    float4 color = desktop.sample(s,uv,level(lower+fraction));
    color.rgb *= 1.0f-0.10f*progress*gradient;
    // Rounded side shadows grow with the fold, like a surface turning away
    // from the light. They shade the live pixels rather than exposing a gutter.
    float edgeDistance = min(in.uv.x,1.0f-in.uv.x);
    float edgeWidth = 0.015f+0.12f*pow(progress,0.75f)*(0.20f+0.80f*pow(outer,1.2f));
    float sideFalloff = exp(-pow(edgeDistance/edgeWidth,2.0f));
    float sideDepth = 0.80f*pow(progress,0.70f)*(0.06f+0.94f*pow(outer,1.4f));
    color.rgb *= 1.0f-sideDepth*sideFalloff;
    return float4(color.rgb,1);
}
