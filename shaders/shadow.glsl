#pragma language glsl3

// Uniform inputs - Physically-based lighting system
uniform Image heightMap;       // Height map texture
uniform vec2 worldSize;        // World dimensions (x, z)
uniform float maxHeight;       // Maximum height of the world
uniform vec3 sunDirection;     // Normalized sun direction vector
uniform vec3 moonDirection;    // Normalized moon direction vector
uniform float moonIntensity;   // Moon light intensity (0-0.35)
uniform vec4 ambientColor;     // Ambient light color

// Day/night transition parameters
uniform float dayNightBlend = 1.0;   // Blend factor between day and night (1.0 = day, 0.0 = night)
uniform float twilightFactor = 0.0;  // How much we're in twilight state (sunrise/sunset)
uniform float shadowSoftness = 0.5;  // Shadow softness parameter (higher = softer)
uniform float time = 0.0;            // Current time for animations

// Shadow ray marching parameters
uniform float adaptiveStepFactor = 0.5;
uniform float stepAcceleration = 0.1;
uniform float maxStepMultiplier = 3.0;
uniform float penumbraDistanceScale = 0.02;
uniform float shadowAccumulationLimit = 3.0;
uniform float heightDifferenceScale = 1.0;
uniform float lowAngleThreshold = 0.05;
uniform float lowAngleTransitionSteepness = 15.0;

// Water rendering parameters
uniform float waveFrequencyX = 20.0;
uniform float waveFrequencyY = 15.0;
uniform float waveTimeScale = 0.5;
uniform float waveAmplitude = 0.05;
uniform float ambientReduction = 0.8;

// Terrain detail parameters
uniform float detailFrequency = 0.5;
uniform float detailAmplitude = 0.05;
uniform float goldenHourHueShift = 0.2;
uniform float goldenHourSaturationBoost = 0.3;

// Unified transition function (generalized logistic function)
// Matches Lua implementation for consistency
float transition(float x, float midpoint, float steepness, float min_val, float max_val) {
    return min_val + (max_val - min_val) / (1.0 + exp(-steepness * (x - midpoint)));
}

// Bell curve function centered at a specific point
// Matches Lua implementation for consistency
float timeBell(float value, float center, float width) {
    float diff = abs(value - center);
    return exp(-(diff * diff) / width);
}

// Cyclical function that smoothly varies with time
// Matches Lua implementation for consistency
float cyclical(float value, float period, float phase, float min_val, float max_val) {
    float angle = ((value / period) * 2.0 * 3.14159265) + phase;
    float normalized = (sin(angle) + 1.0) / 2.0;
    return min_val + (max_val - min_val) * normalized;
}

// Precalculate common lighting factors using unified transition function
// This ensures perfectly smooth transitions at all positions including dawn/dusk
float calculateLightFactor(vec3 direction, float intensity) {
    // Convert direction.y from -1,1 to 0,1 range for sigmoid
    float normalizedHeight = (direction.y + 1.0) / 2.0;
    
    // Use unified transition function with same parameters as Lua
    float heightFactor = transition(normalizedHeight, 0.45, 10.0, 0.0, 1.0);
    
    return heightFactor * intensity;
}

// Optimized ray marching for shadow detection
// Returns 1.0 for fully lit, 0.0 for fully shadowed
float calculateShadow(vec2 startPos, float startHeight, vec3 lightDir, float softness) {
    // Use unified transition function instead of hard cutoff for low light angles
    // This prevents sudden shadow changes at dawn/dusk
    float lightAngleFactor = transition(lightDir.y, lowAngleThreshold, lowAngleTransitionSteepness, 0.0, 1.0);
    
    // Early exit with smooth transition for low light angles
    if (lightAngleFactor < 0.01) return 0.0;
    
    // Adaptive step size based on light angle and distance
    // Closer to horizontal = smaller steps needed
    float baseStepSize = 1.0 / max(worldSize.x, worldSize.y);
    float adaptiveStepSize = baseStepSize * (adaptiveStepFactor + lightDir.y); // Smaller steps for low sun angles
    
    vec2 rayStep = vec2(lightDir.x, lightDir.z) * adaptiveStepSize;
    vec2 rayPos = startPos;
    
    // Calculate the maximum number of steps based on world size
    // This helps avoid unnecessary iterations
    int maxSteps = int(min(64.0, length(worldSize) / length(rayStep)));
    
    // Optimization: precalculate ray height slope
    float rayHeightSlope = lightDir.y * worldSize.x;
    
    // Ray march with acceleration
    float stepMultiplier = 1.0;
    
    // Penumbra calculation variables - help create soft shadows
    float shadowAccum = 0.0;
    float shadowCount = 0.0;
    
    for (int i = 0; i < maxSteps; i++) {
        // Apply increasing step size for distant sampling (optimization)
        rayPos += rayStep * stepMultiplier;
        
        // Progressively increase step size to sample more sparsely far from origin
        if (i > 10) stepMultiplier = min(maxStepMultiplier, stepMultiplier + stepAcceleration);
        
        // Stop if we've gone outside the texture
        if (rayPos.x < 0.0 || rayPos.x > 1.0 || rayPos.y < 0.0 || rayPos.y > 1.0) {
            // Apply accumulated shadow contribution if any
            return shadowCount > 0.0 ? 1.0 - (shadowAccum / shadowCount) : 1.0;
        }
        
        // Get height at this ray position
        float terrainHeight = Texel(heightMap, rayPos).r * maxHeight;
        
        // Calculate height of the ray at this position
        float rayDist = distance(startPos, rayPos);
        float rayPathHeight = startHeight + rayDist * rayHeightSlope;
        
        // Calculate difference between terrain and ray height
        float heightDiff = terrainHeight - rayPathHeight;
        
        // If terrain blocks the light ray, contribute to shadow
        if (heightDiff > 0.0) {
            // For sharp shadows, just return immediately
            if (softness <= 0.05) {
                return 0.0;
            }
            
            // For soft shadows, calculate a penumbra effect
            // The shadow softness increases with distance from the blocker
            float penumbraSize = rayDist * penumbraDistanceScale * softness;
            float shadowContribution = min(1.0, heightDiff / (maxHeight * penumbraSize * heightDifferenceScale));
            
            // Accumulate shadow contribution
            shadowAccum += shadowContribution;
            shadowCount += 1.0;
            
            // Early exit for strong shadows
            if (shadowAccum >= shadowAccumulationLimit) {
                return 0.0;
            }
        }
    }
    
    // If we got here with shadow contributions, calculate average
    if (shadowCount > 0.0) {
        return 1.0 - min(1.0, shadowAccum / shadowCount);
    }
    
    // No obstacles found
    return 1.0;
}

// Fragment shader
vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
    // Get the base color from the color texture
    vec4 baseColor = Texel(tex, texture_coords);
    
    // Get height at current position
    float currentHeight = Texel(heightMap, texture_coords).r * maxHeight;
    
    // Fast path: if height is 0, it's deep water with no shadows
    if (currentHeight < 0.01) {
        // Apply wave effect to water based on time
        float waveEffect = sin(texture_coords.x * waveFrequencyX + texture_coords.y * waveFrequencyY + time * waveTimeScale) * waveAmplitude + (1.0 - waveAmplitude);
        
        // Simple water color without special twilight effects
        vec4 waterColor = baseColor * ambientColor * ambientReduction;
        
        return waterColor * waveEffect;
    }
    
    // Continuous light factors using unified transition function
    // These precisely match the calculations in the Lua lighting system
    float sunNormalized = (sunDirection.y + 1.0) / 2.0;
    float moonNormalized = (moonDirection.y + 1.0) / 2.0;
    
    // Use same parameters as in Lua lighting.calculateSkyBrightness
    float sunFactor = transition(sunNormalized, 0.45, 10.0, 0.0, 1.0);
    float moonFactor = transition(moonNormalized, 0.45, 10.0, 0.0, moonIntensity);
    
    // Calculate presence of direct light using unified transition function
    float sunLightPresence = transition(sunDirection.y + 0.1, 0.0, 15.0, 0.0, 1.0);
    float moonLightPresence = transition(moonDirection.y + 0.1, 0.0, 15.0, 0.0, 0.5);
    float hasDirectLight = min(1.0, sunLightPresence + moonLightPresence);
    
    // If very little direct light (smooth transition), use ambient-dominated lighting
    if (hasDirectLight < 0.01) {
        return baseColor * ambientColor;
    }
    
    // Calculate sun and moon shadow contributions separately with continuous transitions
    vec3 sunLightDir = sunDirection;
    vec3 moonLightDir = moonDirection;
    
    // Continuous influence factors using unified transition function
    // These match exactly the Lua lighting.calculateLightProperties
    float sunInfluence = transition(sunNormalized, 0.4, 12.0, 0.0, 1.0);
    float moonInfluence = transition(moonNormalized, 0.4, 12.0, 0.0, 1.0) * moonIntensity * 2.0;
    
    // Prevent divide-by-zero with simple normalization
    float totalInfluence = sunInfluence + moonInfluence + 0.001;
    sunInfluence = sunInfluence / totalInfluence;
    moonInfluence = moonInfluence / totalInfluence;
    
    // Create a local shadow softness value with continuous adjustment
    float localShadowSoftness = shadowSoftness;
    
    // Ensure shadow softness has a reasonable value with linear adjustment
    if (localShadowSoftness <= 0.01 || localShadowSoftness > 3.0) {
        // Base shadow softness with linear transition based on height
        float sunSoftness = 1.0 - 0.7 * max(0.0, min(1.0, sunDirection.y / 0.7));
        float moonSoftness = 1.2; // Moon shadows are always softer
        
        // Blend softness based on light source influences
        localShadowSoftness = sunSoftness * sunInfluence + moonSoftness * moonInfluence;
    }
    
    // Continuous shadow strength using unified transition function
    // These match the calculations in the Lua lighting.calculateShadowProperties
    float sunShadowStrength = 0.3 + 0.5 * transition(sunNormalized, 0.3, 10.0, 0.0, 1.0);
    float moonShadowStrength = 0.25 * transition(moonNormalized, 0.3, 10.0, 0.0, 1.0);
    
    // Continuous light intensity calculations using unified transition function
    float sunLightIntensity = 0.3 + 0.7 * transition(sunNormalized, 0.4, 12.0, 0.0, 1.0);
    float moonLightIntensity = 0.2 + 0.3 * transition(moonNormalized, 0.4, 12.0, 0.0, 1.0);
    
    // Instead of choosing one dominant light source, we'll calculate both
    // and blend the results based on influence
    vec3 lightDir = sunLightDir * sunInfluence + moonLightDir * moonInfluence;
    float shadowStrength = sunShadowStrength * sunInfluence + moonShadowStrength * moonInfluence;
    float lightIntensity = sunLightIntensity * sunInfluence + moonLightIntensity * moonInfluence;
    
    // Calculate shadow factors using unified transition function
    // Matches Lua shadow calculations
    float sunHeightFactor = transition(sunDirection.y + 0.1, 0.0, 15.0, 0.0, 1.0);
    float moonHeightFactor = transition(moonDirection.y + 0.05, 0.0, 15.0, 0.0, 1.0);
    
    float sunShadowFactor = sunHeightFactor * 
        calculateShadow(texture_coords, currentHeight, sunLightDir, 
                      localShadowSoftness * (1.0 - 0.3 * sunInfluence));
                       
    float moonShadowFactor = moonHeightFactor * 
        calculateShadow(texture_coords, currentHeight, moonLightDir, 
                      localShadowSoftness * (1.0 + 0.2 * moonInfluence));
    
    // Create base lighting components with unified transition function
    // These perfectly match the Lua calculations
    vec4 sunLight = baseColor * color * (0.3 + 0.7 * transition(sunNormalized, 0.4, 12.0, 0.0, 1.0));
    vec4 moonLight = baseColor * color * (0.2 + 0.3 * transition(moonNormalized, 0.4, 12.0, 0.0, 1.0));
    vec4 ambientLight = baseColor * ambientColor;
    
    // Calculate any special dawn/dusk effects using the bell curve function
    // This creates beautiful golden hour lighting at 6am/6pm
    float hour = fract(time / 60.0) * 24.0;
    
    // Calculate dawn factor (centered at 6am)
    float dawnFactor = timeBell(hour, 6.0, 0.5) * twilightFactor;
    
    // Calculate dusk factor (centered at 6pm/18hr)
    float duskFactor = timeBell(hour, 18.0, 0.5) * twilightFactor;
    
    // Combined dawn/dusk factor
    float dawnDuskFactor = dawnFactor + duskFactor;
    
    // Apply golden hour enhancement to light colors
    if (dawnDuskFactor > 0.01) {
        sunLight.r *= (1.0 + dawnDuskFactor * goldenHourHueShift);
        sunLight.g *= (1.0 + dawnDuskFactor * goldenHourSaturationBoost);
        sunLight.b *= (1.0 - dawnDuskFactor * goldenHourSaturationBoost);
        
        moonLight.r *= (1.0 + dawnDuskFactor * goldenHourHueShift * 0.7);
        moonLight.g *= (1.0 + dawnDuskFactor * goldenHourSaturationBoost * 0.5);
    }
    
    // Continuous shadow transitions
    float sunShadowTransition = sunShadowFactor;
    float moonShadowTransition = moonShadowFactor;
    
    // Apply shadows to each light source individually for better control
    vec4 shadowedSunLight = mix(
        mix(ambientLight, sunLight, 0.3), // Shadowed areas still get some sun light
        sunLight,                         // Fully lit areas
        sunShadowTransition               // Smooth transition between states
    );
    
    vec4 shadowedMoonLight = mix(
        mix(ambientLight, moonLight, 0.3), // Shadowed areas still get some moon light
        moonLight,                         // Fully lit areas
        moonShadowTransition               // Smooth transition between states
    );
    
    // Blend the shadowed light components based on celestial influence
    vec4 shadowedLight = shadowedSunLight * sunInfluence + 
                         shadowedMoonLight * moonInfluence;
    
    // Terrain detail enhancement - slight variation based on height
    float terrainDetail = 1.0 + (sin(currentHeight * detailFrequency) * detailAmplitude);
    
    // Apply dawn/dusk enhancement for beautiful golden hour transitions
    vec4 finalColor = shadowedLight;
    
    // Apply subtle color enhancement at dawn/dusk (6am/6pm)
    if (dawnDuskFactor > 0.01) {
        // Golden hour color enhancement - perfectly smooth transitions
        finalColor.r *= (1.0 + dawnDuskFactor * goldenHourHueShift);
        finalColor.g *= (1.0 + dawnDuskFactor * goldenHourSaturationBoost);
        finalColor.b *= max(0.8, 1.0 - dawnDuskFactor * goldenHourSaturationBoost);
    }
    
    // Apply terrain detail variation
    finalColor *= terrainDetail;
    
    return finalColor;
}
