[![ReShade FXC](https://github.com/clshortfuse/reshade-shaders/actions/workflows/reshade-fxc.yml/badge.svg)](https://github.com/clshortfuse/reshade-shaders/actions/workflows/reshade-fxc.yml)

ReShade FX shaders
==================

This repository aims to collect post-processing shaders written in the ReShade FX shader language.

Installation
------------

1. [Download](https://github.com/clshortfuse/reshade-shaders/archive/refs/heads/main.zip) this repository
2. Extract the downloaded archive file somewhere
3. Start your game, open the ReShade in-game menu and switch to the "Settings" tab
4. Add the path to the extracted [Shaders](/Shaders) folder to "Effect Search Paths"
5. Add the path to the extracted [Textures](/Textures) folder to "Texture Search Paths"
6. Switch back to the "Home" tab and click on "Reload" to load the shaders

Contributing
------------

1. Clone Repo
2. Copy [Reshade.fxh](https://raw.githubusercontent.com/crosire/reshade-shaders/refs/heads/slim/Shaders/ReShade.fxh) and [ReshadeUI.fxh](https://raw.githubusercontent.com/crosire/reshade-shaders/refs/heads/slim/Shaders/ReShadeUI.fxh) from official repo to [Shaders](/Shaders) folder.
