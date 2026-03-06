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
- si la racine noVNC ne s'affiche pas correctement: `http://localhost:6080/vnc.html`
- API de contrôle : `http://localhost:8001/api/health`

Notes:
- ce lancement démarre le service CPU `ros2_container`, pas le profil GPU
- les logs du conteneur affichent les ports internes `6080` et `8001`; côté hôte, il faut utiliser `6080` et `8001`

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
- si la racine noVNC ne s'affiche pas correctement: `http://localhost:6081/vnc.html`
- API de contrôle : `http://localhost:8002/api/health`

Notes:
- ce lancement démarre le service `ros2_container-gpu`
- les logs du conteneur continuent d'afficher les ports internes `6080` et `8001`; côté hôte, il faut utiliser `6081` et `8002`

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

Le conteneur est autonome :

- aucun import Python depuis un autre dépôt
- aucun besoin de monter `BT_Navigator`
- les assets Nav2 nécessaires sont déjà embarqués dans `runtime/BT_Navigator/`

Les scripts `scripts/*.sh` s’appuient uniquement sur ce runtime local et permettent
de relancer la navigation seule sans arrêter Gazebo ni AMCL.

## Notes performance / stabilite

- Par defaut, le conteneur force le rendu logiciel (`LIBGL_ALWAYS_SOFTWARE=1`).
- Le bureau noVNC repose sur `websockify -> x11vnc -> Xvfb`; si le websocket s'ouvre mais que le bureau reste vide, verifier les logs `x11vnc` du conteneur.
- Si Gazebo/RViz est lent : réduire la résolution via `VNC_RESOLUTION` dans `compose.yaml`, ou lancer la démo avec `--no-rviz`.

