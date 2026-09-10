#include <metal_stdlib>
using namespace metal;
struct VertexOut { float4 position [[position]]; float2 uv; };
struct Params { float progress, width, height, reducedMotion; float opacity, pad0, pad1, pad2; };

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
    // Project the physical lid back onto the gesture's original image plane.
    // Both axes share one perspective denominator. The old independent power
    // warps expanded content sideways and pinned the top instead of revealing it.
    float rotation = min(72.0f,-40.0f*log(max(0.001f,1.0f-progress)))*M_PI_F/180.0f;
    rotation *= 1.0f-p.reducedMotion;
    float perspective = 1.0f/(1.0f-outer*sin(rotation)/2.7f);
    float2 uv = float2(0.5f+(in.uv.x-0.5f)*perspective,outer*cos(rotation)*perspective);
    float gradient = pow(outer,2.65f);
    float sigma = 40.0f*pow(progress,0.75f)*gradient*p.width/1600.0f;
    // Interpolate variance between adjacent prefiltered levels for a continuous
    // focus field. At zero progress the original, unfiltered image is exact.
    const float kernelVariance = 7.4790772f;
    float lod = 0.5f*log2(1.0f+3.0f*sigma*sigma/kernelVariance);
    float lower = floor(lod);
    float variance0 = (exp2(2.0f*lower)-1.0f)*kernelVariance/3.0f;
    float variance1 = (exp2(2.0f*(lower+1.0f))-1.0f)*kernelVariance/3.0f;
    float fraction = clamp((sigma*sigma-variance0)/max(variance1-variance0,0.001f),0.0f,1.0f);
    float4 color = desktop.sample(s,uv,level(lower+fraction));
    color.rgb *= 1.0f-0.24f*progress*pow(outer,3.0f);
    // The panel moves past the image's sides. These wedges are revealed by
    // projection, not painted on top of otherwise stretched desktop pixels.
    float edge = 0.5f-abs(uv.x-0.5f);
    float softness = 0.003f+0.008f*progress;
    float coverage = smoothstep(-softness,softness,edge);
    coverage = mix(1.0f,coverage,smoothstep(0.0f,0.04f,progress));
    color.rgb *= mix(0.008f,1.0f,coverage);
    float3 live = desktop.sample(s,float2(in.uv.x,outer),level(0)).rgb;
    return float4(mix(live,color.rgb,p.opacity),1);
}
