# ROS2_Container

## ROS2 Humble Desktop dans le navigateur (noVNC)

## Démarrage (CPU par défaut)

Depuis la racine du repo :

```bash
docker compose up --build
```

Puis ouvrir :
- `http://localhost:6080`

Dans le bureau XFCE, ouvrir un terminal et vérifier :

```bash
ros2 --help
```

## Démarrage (GPU NVIDIA optionnel)

Pré-requis :
- Docker avec support GPU NVIDIA (NVIDIA Container Toolkit)

Lancer le profil GPU :

```bash
docker compose --profile gpu up --build
```

Puis ouvrir :
- `http://localhost:6081`

## Notes performance / stabilité

- Par défaut, le conteneur force le rendu logiciel (`LIBGL_ALWAYS_SOFTWARE=1`).\n
- Si Gazebo/RViz est lent : réduire la résolution via `VNC_RESOLUTION` dans `compose.yaml`, ou lancer la démo avec `--no-rviz`.

