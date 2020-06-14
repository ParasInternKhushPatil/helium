#!/usr/bin/env bash
DISTRO="melodic"

set -e
IWD="~"

# Preventing sudo timeout https://serverfault.com/a/833888
trap "exit" INT TERM; trap "kill 0" EXIT; sudo -v || exit $?; sleep 1; while true; do sleep 60; sudo -nv; done 2>/dev/null &

# 0 Prerequisites

sudo apt install git -y

# 1 ROS (and Gazebo)

sudo sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list'

sudo apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654

sudo apt update

sudo apt install ros-$DISTRO-desktop-full -y

echo "source /opt/ros/$DISTRO/setup.bash" >> ~/.bashrc
source ~/.bashrc

sudo apt install python-rosdep python-rosinstall python-rosinstall-generator python-wstool build-essential -y

sudo rosdep init || true
rosdep update

# 2 Ardupilot

cd $IWD
if [ ! -d "ardupilot" ]; then

    #git clone https://github.com/ArduPilot/ardupilot
    git clone https://github.com/yanhwee/ardupilot.git
    cd ardupilot
    git submodule update --init --recursive

fi

cd $IWD/ardupilot

Tools/environment_install/install-prereqs-ubuntu.sh -y

. ~/.profile

# 3 Ardupilot Gazebo Plugin (khancyr)

cd $IWD
if [ ! -d "ardupilot_gazebo" ]; then

    #git clone https://github.com/khancyr/ardupilot_gazebo
    git clone https://github.com/yanhwee/ardupilot_gazebo.git
    cd ardupilot_gazebo
    mkdir build
    cd build
    cmake ..
    make -j4
    sudo make install

    echo 'source /usr/share/gazebo/setup.sh' >> ~/.bashrc

    echo 'export GAZEBO_MODEL_PATH=~/ardupilot_gazebo/models' >> ~/.bashrc

    echo 'export GAZEBO_RESOURCE_PATH=~/ardupilot_gazebo/worlds:${GAZEBO_RESOURCE_PATH}' >> ~/.bashrc

    source ~/.bashrc

fi

# 4 MAVROS

sudo apt-get install ros-$DISTRO-mavros ros-$DISTRO-mavros-extras -y

wget -O - https://raw.githubusercontent.com/mavlink/mavros/master/mavros/scripts/install_geographiclib_datasets.sh | sudo bash

# 5 Recommended

sudo apt-get install python-catkin-tools -y

# 6 Optional

sudo apt-get install ros-$DISTRO-rqt ros-$DISTRO-rqt-common-plugins -y


# Helium

# 1 QGroundControl

if [ ! -f "QGroundControl.AppImage" ]; then

    wget https://s3-us-west-2.amazonaws.com/qgroundcontrol/builds/master/QGroundControl.AppImage

fi

# 2 Catkin Workspace & Package

cd $IWD
if [ ! -d "catkin_ws" ]; then

    mkdir -p catkin_ws/src
    cd catkin_ws/
    catkin init

fi

cd $IWD/catkin_ws/src
if [ ! -d "helium" ]; then

    git clone https://github.com/yanhwee/helium.git
    catkin build

    echo 'source $IWD/catkin_ws/devel/setup.bash' >> ~/.bashrc

    echo 'source $IWD/catkin_ws/src/helium/setup.bash' >> ~/.bashrc

    source ~/.bashrc

fi

# 3 pymavlink

pip3 install pymavlink