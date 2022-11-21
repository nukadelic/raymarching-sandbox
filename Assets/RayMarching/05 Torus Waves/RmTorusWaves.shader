Shader "Raymarching/RmTorusWaves"
{
    Properties
    {
        _ColorA("Color A", Color) = (1,1,0,1)
        _ColorB("Color B", Color) = (1,1,0,1)
        //_ColorB("Color B", Color) = (0,1,0,1)
        //_Position("Position", Vector) = (1,1,1,0)
        [IntRange] _Int1("Int1", Range(-4000,4000)) = 400
        [IntRange] _Int2("Int2", Range(-4000,4000)) = 100
        [IntRange] _Int3("Int3", Range(-4000,4000)) = 100
        [IntRange] _Int4("Int4", Range(-4000,4000)) = 1100

        _LineGradient("Line Gradient", Range(0.1, 1.0)) = 1

        _Complexity("Shader Complexity", Range(0.01, 0.5)) = 0.1
        
        _Opacity("Opacity", Range(0, 1.0)) = 1
    }

    SubShader
    {
        Tags { "Queue" = "Transparent" "IgnoreProjector" = "True" "RenderType" = "Transparent" }
        
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha
        Cull front
        
        LOD 100

        Pass
        {
            CGPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag

            #define MAX_STEPS 100
            #define MAX_DIST 100
            #define SURF_DIST 1e-3

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 ro : TEXCOORD1;
                float3 hitPos : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                // https://youtu.be/S8AWd66hoCo?t=1229
                o.ro = mul( unity_WorldToObject, float4( _WorldSpaceCameraPos , 1 ) );
                o.hitPos = v.vertex;
                return o;
            }

            float3 opU(float3 d1, float3 d2)
            {
                return (d1.x < d2.x) ? d1 : d2;
            }

            float sdSphere( float3 p, float s)
            {
                return length( p ) - s;
            }

            float AA(float d)
            {
                // https://mortoray.com/2015/06/19/antialiasing-with-a-signed-distance-field/
                return clamp( 1 - d , 0 , 1 );
            }

            float3 sdtSphere( float3 value, float3 p, float s, float color )
            {
                float d = sdSphere(p, s);

                return opU( value, float3( d, color, 1 ) );
            }

            float3 Map( float3 p )
            {
                float3 res = float3(1e10, 0, 0);

                res = sdtSphere(res, p - float3(_SinTime.z / 2, 0, 0), .1, 2.6);
                res = sdtSphere(res, p - float3(0, _SinTime.z / 2, 0), .2, 6.6);
                res = sdtSphere(res, p - float3(0, 0, _SinTime.z / 2), .3, 7.6);

                return res;
            }

            float raycast(float3 ro, float3 rd)
            {
                // start at the camera position and march along the camera array 
                // keep track of the [ dO ] distance from the Origin 
                float dO = 0; 

                // keep track of the distance of the scene / surface 
                float dS;

                for (int i=0;i < MAX_STEPS;i++) 
                {
                    // ray marching position 
                    float3 p = ro + dO * rd;

                    float3 res = Map(p);

                    dS = res.x;

                    //// move forward along the ray 
                    dO += dS;

                    //// check if we hit an object ( or reached max / infinity ) 
                    if ( dO < SURF_DIST || dO > MAX_DIST ) break;
                }

                return dO;
            }

            float3 GetNormal(float3 p)
            {
                float2 e = float2( 1e-2 , 0 );

                float3 n = Map(p).x - float3(
                    Map(p - e.xyy).x,
                    Map(p - e.yxy).x,
                    Map(p - e.yyx).x
                );

                return normalize(n);
            }

            float calcAO(float3 pos, float3 nor)
            {
                float occ = 0.0;
                float sca = 1.0;

                for (int i = 0; i < 5; i++)
                {
                    float h = 0.01 + 0.12 * float(i) / 4.0;
                    float d = Map(pos + h * nor).x;
                    occ += (h - d) * sca;
                    sca *= 0.95;
                    if (occ > 0.35) break;
                }
                return clamp(1.0 - 3.0 * occ, 0.0, 1.0) * (0.5 + 0.5 * nor.y);
            }

            float3 render(float3 ro, float3 rd, float2 res)
            {
                // https://www.shadertoy.com/view/Xds3zN

                float t = res.x;
                float c = res.y;

                float3 col = 0.2 + 0.2 * sin( c * 2.0 + float3( 0.0, 1.0, 2.0 ) );

                float3 pos = ro + rd * t;
                float3 nor = GetNormal(pos);

                float ks = 1.0;

                // -------- lighting ---------

                float occ = 1;

                // AO
                //acc = calcAO(pos, nor);

                float3 lin = 0;

                // sun
                {
                    float3  lig = normalize(float3(-0.5, 0.4, -0.6));
                    float3  hal = normalize(lig - rd);
                    float dif = clamp(dot(nor, lig), 0.0, 1.0);
                    //if( dif>0.0001 )
                    //dif *= calcSoftshadow(pos, lig, 0.02, 2.5);
                    float spe = pow(clamp(dot(nor, hal), 0.0, 1.0), 16.0);
                    spe *= dif;
                    spe *= 0.04 + 0.96 * pow(clamp(1.0 - dot(hal, lig), 0.0, 1.0), 5.0);
                    lin += col * 2.20 * dif * float3(1.30, 1.00, 0.70);
                    lin += 5.00 * spe * float3(1.30, 1.00, 0.70) * ks;
                }

                // back
                //{
                //    float dif = clamp(dot(nor, normalize(float3(0.5, 0.0, 0.6))), 0.0, 1.0) * clamp(1.0 - pos.y, 0.0, 1.0);
                //    dif *= occ;
                //    lin += col * 0.55 * dif * float3(0.25, 0.25, 0.25);
                //}

                // sss
                {
                    float dif = pow(clamp(1.0 + dot(nor, rd), 0.0, 1.0), 2.0);
                    dif *= occ;
                    lin += col * 0.25 * dif * float3(1.00, 1.00, 1.00);
                }

                
                col = lerp(lin, float3(0.7, 0.7, 0.9), 1.0 - exp(-0.0001 * t * t * t));
                col = clamp(col, 0.0, 1.0);

                return col;
            }

            float4 raymarch(v2f i)
            {
                float2 uv = i.uv - .5;

                // ray origin / camera 
                float3 ro = i.ro;

                // ray direction 
                float3 rd = normalize(i.hitPos - ro);

                float4 col = 0;

                float d = raycast(ro, rd);

                if (d >= MAX_DIST)  discard;

                else
                {
                    // // Preview normals : 
                    // float3 p = ro + rd * d;
                    // float3 n = GetNormal(p);
                    // col.rgb = n;

                    float3 res = Map(ro + d * rd);

                    float c = res.y;

                    if (c > -.5)
                    {
                        float3 render_color = render(ro, rd, float2(d, c));

                        col = float4(render_color, AA(res.x));
                    }
                }

                return col;
            }

            int _Int1;
            int _Int2;
            int _Int3;
            int _Int4;

            float torusSDF(float3 p , float t )
            {
                float i1 = _Int1 / 1000.0;
                float i2 = _Int2 / 1000.0;
                float i3 = _Int3 / 1000.0;
                float i4 = _Int4 / 1000.0;

                return length(float2( length( p.xy  ) - i1, p.z ) ) - i2 * abs( _SinTime.z / i3 - i4 );
            }

            //float s(v p) {
            //    return length(vec2(length(p.xy) - .5, p.z)) - .6 * (sin(iTime) - 1.1);        // torus SDF
            //}

            float4 _ColorA;
            float4 _ColorB;

            float _LineGradient;
            float _Opacity;
            float _Complexity;

            fixed4 frag(v2f i) : SV_Target
            {
                // return raymarch(i);
                
                // https://www.shadertoy.com/view/ft3cz4
                
                float3 q = - i.ro;                      // ray origin / camera 
                float3 rd = normalize(i.hitPos - q);     // ray direction 
                float4 c = float4( 0,0,0, 1 );

                float lg = _LineGradient / 100.0;

                float t = .1; // raymarching distance
                float u = .1; // line gradient 
                
                float sdf;
                float g;

                float step = _Complexity;

                for( ; t < 3. && u > 0.      // not too far or inside                    
                     ; t += .1 * u + step )  // small nonzero step
                { 
                    u = torusSDF( rd * t - q , t );

                    if (u > 3.) break;
                    
                    // finite difference line gradient
                    float fd = torusSDF( rd * ( t - lg ) - q , t );
                    
                    g = abs( u - fd );

                    float3 glow = lerp( _ColorA.xyz, _ColorB.xyz, t );

                    // glow, bright when sdf->0
                    c.xyz += 2e-5 * glow / g;     
                }

                /*
                q = i.ro;
                d = normalize(i.hitPos - q);
                for (float t = .1, u = t, g; t < 3. && u > 0.; t += .1 * u + .01)
                {
                    g = abs((u = s(d * t - q)) - s(d * (t - lg) - q));
                    c.xyz += 2e-5 * _ColorB.xyz / g ;
                }
                */

                c = tanh(c);
                //c = pow(tanh(c), _OpacityBump);
                float op = pow(max(max(c.x,c.y),c.z), 4*(1-_Opacity) );
                c = lerp( c , op * c , 1-_Opacity );
                //c = tanh(c);                            // prevent overexposure
                
                return c ;
            }
            
            ENDCG
        }
    }
}
