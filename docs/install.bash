#!/usr/bin/env bash -i
set -e
set -x

DISTRO="noetic"
IWD="$HOME"

# Preventing sudo timeout https://serverfault.com/a/833888
trap "exit" INT TERM; trap "kill 0" EXIT; sudo -v || exit $?; sleep 1; while true; do sleep 60; sudo -nv; done 2>/dev/null &

# 0 Prerequisites

sudo apt install git -y

# 1 ROS (and Gazebo)

sudo sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list'

sudo apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654

sudo apt update

sudo apt install ros-$DISTRO-desktop-full -y

if ! grep -q "source /opt/ros/$DISTRO/setup.bash" ~/.bashrc; then
    echo "source /opt/ros/$DISTRO/setup.bash" >> ~/.bashrc
    source ~/.bashrc
fi

sudo apt install python3-rosdep python3-rosinstall python3-rosinstall-generator python3-wstool build-essential -y

sudo rosdep init || true
rosdep update

# 2 Ardupilot

cd $IWD
if [ ! -d "ardupilot" ]; then
    git clone https://github.com/ArduPilot/ardupilot
fi

cd ardupilot

git submodule update --init --recursive

bash Tools/environment_install/install-prereqs-ubuntu.sh -y || true

. ~/.profile

# 3 Ardupilot Gazebo Plugin (khancyr)

cd $IWD
if [ ! -d "ardupilot_gazebo" ]; then
    #git clone https://github.com/khancyr/ardupilot_gazebo
    git clone https://github.com/ParasInternKhushPatil/ardupilot_gazebo
fi

cd ardupilot_gazebo
mkdir -p build
cd build
cmake ..
make -j4
sudo make install

if ! grep -q 'source /usr/share/gazebo/setup.sh' ~/.bashrc; then
    echo 'source /usr/share/gazebo/setup.sh' >> ~/.bashrc
fi

if ! grep -q 'export GAZEBO_MODEL_PATH=~/ardupilot_gazebo/models' ~/.bashrc; then
    echo 'export GAZEBO_MODEL_PATH=~/ardupilot_gazebo/models' >> ~/.bashrc
fi

if ! grep -q 'export GAZEBO_RESOURCE_PATH=~/ardupilot_gazebo/worlds:${GAZEBO_RESOURCE_PATH}' ~/.bashrc; then
    echo 'export GAZEBO_RESOURCE_PATH=~/ardupilot_gazebo/worlds:${GAZEBO_RESOURCE_PATH}' >> ~/.bashrc
fi

source ~/.bashrc

# 4 MAVROS

sudo apt-get install ros-$DISTRO-mavros ros-$DISTRO-mavros-extras -y

wget -O - https://raw.githubusercontent.com/mavlink/mavros/master/mavros/scripts/install_geographiclib_datasets.sh | sudo bash

# 5 Recommended

sudo apt-get install python3-catkin-tools -y

# 6 Optional

sudo apt-get install ros-$DISTRO-rqt ros-$DISTRO-rqt-common-plugins -y


# Troubleshooting 2.1
gzserver --verbose &
while [ ! -f $IWD/.ignition/fuel/config.yaml ]; do sleep 1 ; done
killall gzserver
sed -i -e 's,https://api.ignitionfuel.org,https://fuel.ignitionrobotics.org/1.0/models,g' $IWD/.ignition/fuel/config.yaml


### Helium Supporting Stack
PYTHON_SITE_PACKAGES_PATH="$HOME/.local/lib/python3.8/site-packages"
GAZEBO_PROTOBUF_MSGS_PATH="/usr/include/gazebo-11/gazebo/msgs/proto"

# 1A Catkin Workspace

cd $IWD
mkdir -p catkin_ws/src
cd catkin_ws/
catkin_make

# 1B Helium Package

cd $IWD/catkin_ws/src
if [ ! -d "helium" ]; then
    git clone https://github.com/ParasInternKhushPatil/helium.git
fi

source /opt/ros/noetic/setup.bash
catkin build

if ! grep -q "source $IWD/catkin_ws/devel/setup.bash" ~/.bashrc; then
    echo "source $IWD/catkin_ws/devel/setup.bash" >> ~/.bashrc
fi

if ! grep -q "source $IWD/catkin_ws/src/helium/setup.bash" ~/.bashrc; then
    echo "source $IWD/catkin_ws/src/helium/setup.bash" >> ~/.bashrc
fi

source ~/.bashrc

# 2 QGroundControl (QGC)

cd $IWD

sudo apt install gstreamer1.0-plugins-bad gstreamer1.0-libav gstreamer1.0-gl -y

if [ ! -f "QGroundControl.AppImage" ]; then
    wget https://s3-us-west-2.amazonaws.com/qgroundcontrol/latest/QGroundControl.AppImage
fi

chmod +x ./QGroundControl.AppImage

# 3 Google Protobufs

cd $IWD
if [ ! -d "protobuf" ]; then
    git clone https://github.com/protocolbuffers/protobuf.git
fi

cd protobuf
git submodule update --init --recursive
./autogen.sh

./configure
make
make check
sudo make install
sudo ldconfig # refresh shared library cache.

# 3.1 Python Bindings for Gazebo Protobuf Messages

mkdir -p $PYTHON_SITE_PACKAGES_PATH/proto
cd $PYTHON_SITE_PACKAGES_PATH/proto

protoc --proto_path=$GAZEBO_PROTOBUF_MSGS_PATH --python_out='.' $GAZEBO_PROTOBUF_MSGS_PATH/*.proto

touch __init__.py

if ! grep -q "PYTHONPATH=\$PYTHONPATH:$PYTHON_SITE_PACKAGES_PATH/proto" ~/.bashrc; then
    echo "PYTHONPATH=\$PYTHONPATH:$PYTHON_SITE_PACKAGES_PATH/proto" >> ~/.bashrc
fi

# 4 Python Libraries

sudo apt install python3-pip -y

python3 -m pip install pymavlink
# https://stackoverflow.com/questions/59910041/getting-module-google-protobuf-descriptor-pool-has-no-attribute-default-in-m
python3 -m pip install python3-protobuf
python3 -m pip install --upgrade protobuf
