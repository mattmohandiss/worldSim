# WorldSim 🌎

A procedural voxel terrain generator and renderer built with LÖVE (Love2D), featuring dynamic day-night cycles, terrain generation, and realistic lighting.

![WorldSim Screenshot](demo.gif)

## Overview

WorldSim generates and renders procedural 3D voxel terrain with realistic lighting. It uses Perlin noise to create varied terrain types including oceans, beaches, plains, mountains, and snow peaks. The world features a dynamic day-night cycle with realistic sun and moon lighting that affects terrain appearance throughout the day.

## Features

- **Procedural Terrain Generation**: Uses multi-octave fractal Perlin noise to create diverse and realistic landscapes
- **Day-Night Cycle**: Complete day-night system with accurate celestial body positions
- **Dynamic Lighting**: Light colors and intensities change based on time of day
  - Golden hour/blue hour transitions
  - Atmospheric scattering simulation
  - Color temperature models for different times of day
- **Weather & Environment**: Top-down visualization with appropriate terrain coloring
- **Custom Shader System**: GLSL shaders for shadow calculations and lighting effects

## Installation

### Requirements

- [LÖVE](https://love2d.org/) 11.3 or newer

### Setup

1. Clone this repository:
   ```
   git clone https://github.com/mattmoandiss/worldSim.git
   cd worldSim
   ```

2. Run using LÖVE:
   ```
   love .
   ```

## Configuration

WorldSim uses a comprehensive configuration system located in `options.lua`. The configuration is organized into four main categories: world generation, lighting system, terrain appearance, and rendering settings.

### Quick Start

For basic customization, modify these commonly used settings in `options.lua`:

```lua
-- World size and generation
world = {
    dimensions = {
        x = 500,  -- World width in voxels
        y = 50,   -- World height (max elevation)
        z = 500   -- World depth in voxels
    },
    generation = {
        seed = nil,        -- nil for random, or specific number like 378613
        tileSize = 15,     -- Size of terrain chunks
        batchSize = 10     -- Generation batch size (affects performance)
    }
}

-- Day/night cycle timing
lighting = {
    temporal = {
        dayLength = 10,    -- Seconds for full day/night cycle
        startHour = 12     -- Starting time of day (0-24)
    }
}
```

### World Generation Settings

Control how the terrain is generated:

- **dimensions**: World size in voxels (x=width, y=height, z=depth)
- **generation.seed**: Set to `nil` for random worlds, or use a specific number for reproducible terrain
- **generation.tileSize**: Size of terrain chunks (affects detail vs performance)
- **generation.batchSize**: Number of chunks generated per frame
- **noise**: Perlin noise parameters controlling terrain shape
  - `octaves`: More octaves = more terrain detail (default: 9)
  - `persistence`: Lower values = smoother terrain (default: 0.55)
  - `scale`: Higher values = more zoomed-in terrain features (default: 1)

### Lighting System Settings

The lighting system has extensive customization options:

#### Basic Lighting
- **temporal.dayLength**: Duration of full day/night cycle in seconds
- **temporal.startHour**: Starting time when simulation begins (0-24)
- **celestial**: Sun and moon positioning and intensity
- **intensity**: Ambient and direct light strength ranges

#### Color and Atmosphere
- **colorTemperature**: Light colors in Kelvin for different times of day
  - Dawn: 2500K (warm orange), Noon: 6500K (white), Night: 10000K (blue)
- **atmosphere**: Atmospheric scattering simulation parameters
- **colorBlending**: HSL color space blending for realistic transitions

#### Advanced Lighting
- **transitions**: Mathematical curve parameters for smooth light changes
- **timeBells**: Bell curve parameters controlling transition timing
- **shadows**: Shadow calculation constants for different lighting conditions

### Terrain Appearance Settings

Customize how different terrain types look:

```lua
terrain = {
    heightThresholds = {
        deepOcean = 0.18,   -- Below this = deep ocean
        ocean = 0.3,        -- Ocean surface level
        beach = 0.35,       -- Beach/shore areas
        grassland = 0.6,    -- Plains and grasslands
        mountain = 0.82     -- Mountain peaks and above
    },
    
    surfaceColors = {
        deepOcean = { r = 0.0, g = 0.0, b = 0.6 },
        ocean = { r = 0.0, g = 0.2, b = 0.8 },
        beach = { r = 0.8, g = 0.7, b = 0.5 },
        grassland = { r = 0.1, g = 0.6, b = 0.1 },
        mountain = { r = 0.5, g = 0.5, b = 0.5 }
    }
}
```

### Rendering Performance Settings

Adjust visual quality vs performance:

- **rendering.shadows**: Shadow ray marching parameters
  - `adaptiveStepFactor`: Shadow calculation precision (lower = higher quality)
  - `maxStepMultiplier`: Maximum shadow ray steps (higher = better quality)
- **rendering.water**: Water surface effects
- **rendering.terrain**: Terrain detail enhancement settings

### Advanced Configuration

⚠️ **Warning**: Advanced parameters use complex mathematical models. Changing these may produce unexpected results.

The `options.lua` file contains additional advanced parameters for:
- Atmospheric scattering coefficients
- HSL color space blending mathematics  
- Shadow softness calculations
- Light intensity curve parameters
- Sky brightness mathematical models

For detailed parameter descriptions, see the LuaLS annotations in `options.lua`.
