# 🌟 Enumium

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Made with Lua](https://img.shields.io/badge/Made%20with-Lua-2C2D72.svg)](https://www.lua.org/)
[![Open Source Love](https://badges.frapsoft.com/os/v2/open-source.svg?v=103)](https://github.com/wowsam3/Enumium)

> **Enumium** is a simple, modern enum system built for developers who want clean, flexible, and powerful code.  
> It makes creating and managing enums effortless — with built-in support for data, validation, and events.  
> Define your enums once and use them anywhere, all with a clear and lightweight API.

---

## ✨ Features
- 🧩 **Simple API** — clean and intuitive syntax  
- ⚙️ **Metadata support** — store data directly inside enums  
- 🧠 **Validation & safety** — prevent invalid values automatically  
- 🔄 **Events & extensions** — hook into enum changes or extend functionality  
- 💡 **Lightweight & fast** — designed for both Roblox and pure Lua  

---

## 🚀 Basic Usage

**Option 1: Roblox**
```lua

local Enumium = require(path.to.enumium)

-- Create an enum
local FruitEnum = Enumium.new("Fruit", {
    Apple = {color = "red"},
    Banana = {color = "yellow"},
    Grape = {color = "purple"},
})

-- Access values
print(FruitEnum.Apple.name)  --> "Apple"
print(FruitEnum.Apple.data.color) --> "red"

-- Validate
print(FruitEnum:IsValid("Banana")) --> true
print(FruitEnum:IsValid("Watermelon")) --> false

-- Iterate
for name, value in FruitEnum:Iterate() do
    print(name, value.data.color)
end
