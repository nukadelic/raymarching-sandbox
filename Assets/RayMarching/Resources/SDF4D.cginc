
// https://github.com/Jellevermandere/4D-Raymarching/blob/master/Assets/Shaders/DistanceFunctions.cginc

// 4D HyperCube
float sdHypercube(float4 p, float4 b)
{
	float4 d = abs(p) - b;
	return min(max(d.x, max(d.y, max(d.z, d.w))), 0.0) + length(max(d, 0.0));
}

float sdCone(float4 p, float4 h)
{
	return max(length(p.xzw) - h.x, abs(p.y) - h.y) - h.x * p.y;
}

float sd16Cell(float4 p, float s)
{
    p = abs(p);
    return (p.x + p.y + p.z + p.w - s) * 0.57735027f;
}
float sd5Cell(float4 p, float4 a)
{
    return (max(max(max(abs(p.x + p.y + (p.w / a.w)) - p.z, abs(p.x - p.y + (p.w / a.w)) + p.z), abs(p.x - p.y - (p.w / a.w)) + p.z), abs(p.x + p.y - (p.w / a.w)) - p.z) - a.x) / sqrt(3.);
}

// plane
float sdPlane(float4 p, float4 s)
{

    float plane = dot(p, normalize(float4(0, 1, 0, 0))) - (sin(p.x * s.x + p.w) + sin(p.z * s.z) + sin((p.x * 0.34 + p.z * 0.21) * s.w)) / s.y;
    return plane;

}
