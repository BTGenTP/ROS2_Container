# ROS2_Container

## ROS2 Humble Desktop dans le navigateur (noVNC)

Le conteneur expose maintenant deux surfaces :

- le bureau XFCE via noVNC
- une API HTTP de contrôle Nav2 pour recevoir un BT XML, démarrer la simulation, relancer la navigation et envoyer un goal

## Démarrage (CPU par défaut)

Depuis la racine du repo :

```bash
docker compose up --build
```

Puis ouvrir :
- `http://localhost:6080`
- API de contrôle : `http://localhost:8001/api/health`

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
- API de contrôle : `http://localhost:8002/api/health`

## API de contrôle Nav2

Endpoints principaux :

- `GET /api/health`
- `GET /api/status`
- `POST /api/bt/upload`
- `POST /api/bt/execute`
- `POST /api/sim/start`
- `POST /api/sim/reset`
- `POST /api/navigation/restart`
- `POST /api/navigation/goal`

Exemple de transfert + exécution :

```bash
curl -X POST http://localhost:8001/api/bt/execute \
  -H "Content-Type: application/json" \
  -d '{
    "xml": "<root main_tree_to_execute=\"MainTree\"></root>",
    "filename": "mission.xml",
    "goal_name": "Station_A",
    "start_stack_if_needed": true,
    "restart_navigation": true
  }'
```

## Runtime persistant

Le runtime persistant est stocké dans `runtime/BT_Navigator/` :

- `behavior_trees/generated/`
- `params/`
- `maps/`
- `config/locations.yaml`
- `logs/`
- `state/pids/`

Les scripts `scripts/*.sh` alimentent ce runtime à partir de `repositories/BT_Navigator/`
et permettent de relancer la navigation seule sans arrêter Gazebo ni AMCL.

## Notes performance / stabilité

- Par défaut, le conteneur force le rendu logiciel (`LIBGL_ALWAYS_SOFTWARE=1`).\n
- Si Gazebo/RViz est lent : réduire la résolution via `VNC_RESOLUTION` dans `compose.yaml`, ou lancer la démo avec `--no-rviz`.

