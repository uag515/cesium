// Thanks for the contribution Jonas
// http://29a.ch/2012/7/19/webgl-terrain-rendering-water-fog

uniform sampler2D specularMap;
uniform sampler2D normalMap;
uniform vec4 baseWaterColor;
uniform vec4 blendColor;
uniform float frequency;
uniform float animationSpeed;
uniform float amplitude;
uniform float specularIntensity;
uniform float zoomedOutSpecularIntensity;
uniform float fadeFactor;

vec4 getNoise(vec2 uv, float time) {

    float cosAngle = 1.0; // cos(angleInRadians);
    float sinAngle = 0.0; // sin(angleInRadians);
    
    // time dependent sampling directions
    vec2 s0 = vec2(1.0/17.0, 0.0);
    vec2 s1 = vec2(-1.0/29.0, 0.0);
    vec2 s2 = vec2(1.0/101.0, 1.0/59.0);
    vec2 s3 = vec2(-1.0/109.0, -1.0/57.0);
    
    // rotate sampling direction by specified angle
    s0 = vec2((cosAngle * s0.x) - (sinAngle * s0.y), (sinAngle * s0.x) + (cosAngle * s0.y));
    s1 = vec2((cosAngle * s1.x) - (sinAngle * s1.y), (sinAngle * s1.x) + (cosAngle * s1.y));
    s2 = vec2((cosAngle * s2.x) - (sinAngle * s2.y), (sinAngle * s2.x) + (cosAngle * s2.y));
    s3 = vec2((cosAngle * s3.x) - (sinAngle * s3.y), (sinAngle * s3.x) + (cosAngle * s3.y));
    
    vec2 uv0 = (uv/103.0) + (time * s0);
    vec2 uv1 = uv/107.0 + (time * s1) + vec2(0.23);
    vec2 uv2 = uv/vec2(897.0, 983.0) + (time * s2) + vec2(0.51);
    vec2 uv3 = uv/vec2(991.0, 877.0) + (time * s3) + vec2(0.71);
    
    uv0 = fract(uv0);
    uv1 = fract(uv1);
    uv2 = fract(uv2);
    uv3 = fract(uv3);
    vec4 noise = (texture2D(normalMap, uv0)) +
                 (texture2D(normalMap, uv1)) +
                 (texture2D(normalMap, uv2)) +
                 (texture2D(normalMap, uv3));
                 
    // average and scale to between -1 and 1
    return ((noise / 4.0) - 0.5) * 2.0;
}

float waveFade(float edge0, float edge1, float x)
{
	float y = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
	return pow(1.0 - y, 5.0);
}

vec4 computeWaterColor(vec3 positionEyeCoordinates, vec2 textureCoordinates, mat3 enuToEye, vec3 imageryColor, float specularMapValue)
{
    float time = czm_frameNumber * animationSpeed;
    
    vec3 positionToEyeEC = -positionEyeCoordinates;
    float positionToEyeECLength = length(positionToEyeEC);

    // The double normalize below works around a bug in Firefox on Android devices.
    vec3 normalizedpositionToEyeEC = normalize(normalize(positionToEyeEC));
    
    // Fade out the waves as the camera moves far from the surface.
    float waveIntensity = waveFade(70000.0, 1000000.0, positionToEyeECLength);
            
    vec4 noise = getNoise(textureCoordinates * frequency, time);
    vec3 normalTangentSpace = noise.xyz * vec3(1.0, 1.0, (1.0 / amplitude));
    
    // fade out the normal perturbation as we move farther from the water surface
    normalTangentSpace.xy *= waveIntensity;
    normalTangentSpace = normalize(normalTangentSpace);
    
    // get ratios for alignment of the new normal vector with a vector perpendicular to the tangent plane
    float tsPerturbationRatio = normalTangentSpace.z;
    
    czm_material material;
    
    material.normal = enuToEye * normalTangentSpace;

    float diffuseIntensity = getLambertDiffuse(czm_sunDirectionEC, material);
    
    const vec3 waveHighlightColor = vec3(0.3, 0.45, 0.6);

    material.emission = imageryColor + mix(waveHighlightColor * 5.0 * (1.0 - tsPerturbationRatio), vec3(0.0), diffuseIntensity);
    material.diffuse = waveHighlightColor;
    material.specular = mix(0.0, mix(zoomedOutSpecularIntensity, specularIntensity, waveIntensity), specularMapValue);
    material.shininess = 10.0;
    
    return czm_phong(normalizedpositionToEyeEC, material);
}
