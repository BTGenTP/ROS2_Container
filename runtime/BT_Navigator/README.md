This runtime tree stores Nav2 artifacts managed by `ROS2_Container`.

- `behavior_trees/generated/`: uploaded or generated BT XML files executed by Nav2
- `params/`: active Nav2 parameter files derived from the base template
- `maps/`: persistent map assets embedded in this repository
- `config/locations.yaml`: named goal poses exposed by the control API
- `logs/` and `state/`: process logs and PID files for Gazebo, localization and navigation

The scripts in `scripts/` use only this tree at runtime. Legacy files under
`behavior_trees/__generated/` are migrated into `behavior_trees/generated/` when needed.
