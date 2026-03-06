This runtime tree stores Nav2 artifacts managed by `ROS2_Container`.

- `behavior_trees/generated/`: uploaded or generated BT XML files executed by Nav2
- `params/`: active Nav2 parameter files derived from the base template
- `maps/`: persistent map assets copied from `repositories/BT_Navigator/maps/`
- `config/locations.yaml`: named goal poses exposed by the control API
- `logs/` and `state/`: process logs and PID files for Gazebo, localization and navigation

The scripts in `scripts/` seed missing files into this tree on first start so the
container can restart only the navigation stack without resetting Gazebo or AMCL.
