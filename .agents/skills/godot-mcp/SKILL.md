---
name: godot-mcp
description: Guía y comandos para interactuar con Godot 4 a través de Godot MCP Pro (inspección de escenas, manipulación de nodos, edición de scripts y pruebas en tiempo real).
---

# Godot MCP Pro — Skills para Asistentes de IA

Tienes acceso a herramientas MCP conectadas directamente al editor de Godot 4:

## Flujos de Trabajo Esenciales

### 1. Explorar el Proyecto
- `get_project_info`: Información general (versión, renderizador, tamaño del viewport).
- `get_filesystem_tree`: Estructura de directorios (filtros: `*.tscn`, `*.gd`).
- `get_scene_tree`: Jerarquía de nodos de la escena actualmente abierta.
- `read_script`: Leer código de cualquier GDScript.
- `get_project_settings`: Configuraciones del proyecto.

### 2. Construir / Modificar Escenas 2D y 3D
- `create_scene`: Crear archivo `.tscn` con nodo raíz especificado.
- `add_node`: Añadir nodos con propiedades.
- `update_property`: Actualizar propiedades de nodos (position, scale, etc.).
- `save_scene`: Guardar cambios de la escena en disco.

### 3. Escribir y Editar Scripts
- `create_script`: Crear un nuevo archivo `.gd`.
- `edit_script`: Modificar scripts existentes (`replacements` o `content`).
- `validate_script`: Verificar sintaxis sin ejecutar.
- `read_script`: Leer código antes de editar.

### 4. Pruebas y Depuración
- `play_scene`: Ejecutar la escena o el juego.
- `get_game_screenshot`: Captura visual del estado del juego en ejecución.
- `capture_frames`: Captura de múltiples frames.
- `get_game_scene_tree`: Árbol de nodos en runtime.
- `get_game_node_properties` / `set_game_node_property`: Consultar o cambiar valores en runtime.
- `simulate_key` / `simulate_action` / `simulate_mouse_click`: Enviar controles al juego.
- `stop_scene`: Detener la ejecución del juego.

### Reglas Clave:
- Propiedades: Formatear strings como `Vector2(100, 200)`, `Color(1, 0, 0, 1)`, etc.
- Guardar frecuentemente con `save_scene`.
