#!/bin/bash

set -o errexit

if [ "$1" != "" ]; then
  WS=$1
else
  WS=`pwd`/ws
fi

if [ "$2" != "" ]; then
  INSTALL_SPACE=$2
else
  INSTALL_SPACE=/opt/sasc
fi


WS=`pwd`/ws
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPOS=${SCRIPTDIR}/gazebo_uctf.rosinstall
OTHER_REPOS=${SCRIPTDIR}/other.rosinstall

# TODO(tfoote) add proper certs for NPS servers
export GIT_SSL_NO_VERIFY=true

if test -d ${INSTALL_SPACE}; then
  echo "Error: Install directory ${INSTALL_SPACE} exists. Please delete it and try again."
  exit 1
fi

mkdir -p ${WS}/src

echo "Cloning from ${REPOS} into ${WS}/src..."
if [ -e ${WS}/src/.rosinstall ]; then
  wstool merge --merge-replace -t ${WS}/src ${REPOS} 
  wstool update -t ${WS}/src
else
  wstool init ${WS}/src ${REPOS}
fi
(cd ${WS}/src/uctf && git submodule update --init --recursive)

echo "Downloading pacakge.xml files for Gazebo packages..."
curl https://bitbucket.org/scpeters/unix-stuff/raw/master/package_xml/package_gazebo.xml > ${WS}/src/gazebo/package.xml
curl https://bitbucket.org/scpeters/unix-stuff/raw/master/package_xml/package_ign-math.xml > ${WS}/src/ign-math/package.xml
curl https://bitbucket.org/scpeters/unix-stuff/raw/master/package_xml/package_ign-msgs.xml > ${WS}/src/ign-msgs/package.xml
curl https://bitbucket.org/scpeters/unix-stuff/raw/master/package_xml/package_ign-tools.xml > ${WS}/src/ign-tools/package.xml
curl https://bitbucket.org/scpeters/unix-stuff/raw/master/package_xml/package_sdformat.xml > ${WS}/src/sdformat/package.xml

mkdir -p ${WS}/other_src
echo "Cloning from ${OTHER_REPOS} into ${WS}/other_src..."
if [ -e ${WS}/other_src/.rosinstall ]; then
  wstool merge --merge-replace -t ${WS}/other_src ${OTHER_REPOS}
  wstool update -t ${WS}/other_src
else
  wstool init ${WS}/other_src ${OTHER_REPOS}
fi

cd ${WS}/other_src/ardupilot
git submodule update --init --recursive

cd ${WS}/other_src/mavlink
git submodule update --init --recursive

echo "Installing dependencies with rosdep..."
. /opt/ros/kinetic/setup.bash
rosdep install --from-path ${WS}/src --ignore-src -y|| true
echo "Installing other dependencies..."
sudo apt-get install -y libxslt1-dev libqwt-dev python-future libignition-transport-dev python-netifaces python-paramiko python3-espeak

# Things for venv3
sudo apt-get install -y python3-django python3-netifaces python3-numpy python3-pil python3-pyqt5 python3-urllib3

# things for venv
sudo apt-get install -y python-numpy python-jinja2




echo "Building Gazebo and friends..."
cd ${WS}
catkin config --init --extend /opt/ros/kinetic -i ${INSTALL_SPACE} --install --isolate-devel
sudo mkdir -p ${INSTALL_SPACE}
sudo chown -R ${USER}:${USER} ${INSTALL_SPACE}
catkin build --verbose

# Install Gazebo models
mkdir -p ${INSTALL_SPACE}/share/gazebo_models
for MODEL in iris_with_standoffs iris_with_standoffs_demo gimbal_small_2d zephyr_delta_wing zephyr_delta_wing_ardupilot_demo sun ground_plane
do
  rsync -av ${WS}/src/gazebo_models/${MODEL} ${INSTALL_SPACE}/share/gazebo_models
done



# echo "Cloning Ardupilot..."
# git clone https://github.com/tfoote/ardupilot.git -b uctf-dev
echo "Building Ardupilot..."
cd ${WS}/other_src/ardupilot
./waf configure --prefix=${INSTALL_SPACE}
./waf
./waf install

echo "installing lxml needed for mavlink"
pip install lxml future pyserial --system --target=${INSTALL_SPACE}/lib/python2.7/dist-packages/ --install-option="--install-scripts=${INSTALL_SPACE}/bin"


echo "Installing mavlink"
cd ${WS}/other_src/mavlink/pymavlink
PYTHONPATH=$PYTHONPATH:${INSTALL_SPACE}/lib/python2.7/dist-packages python setup.py install --prefix=${INSTALL_SPACE} --install-layout=deb

echo "Installing mavproxy"
cd ${WS}/other_src/mavproxy
PYTHONPATH=$PYTHONPATH:${INSTALL_SPACE}/lib/python2.7/dist-packages python setup.py install --prefix=${INSTALL_SPACE} --install-layout=deb


# echo "installing qgroundcontrol"
# wget https://s3-us-west-2.amazonaws.com/qgroundcontrol/latest/QGroundControl.AppImage -O ${INSTALL_SPACE}/bin/qgroundcontrol
# chmod +x ${INSTALL_SPACE}/bin/qgroundcontrol

echo "Installing arbiter and dependencies"

VENV3=${INSTALL_SPACE}/venv3
mkdir -p ${VENV3}
pyvenv --system-site-packages ${VENV3} 
(. ${VENV3}/bin/activate && pip3 install wheel)
(. ${VENV3}/bin/activate && pip3 install future image mavproxy netifaces catkin-pkg rospkg)

(. ${VENV3}/bin/activate && cd ${WS}/other_src/acs_lib && python setup.py install)
(. ${VENV3}/bin/activate && cd ${WS}/other_src/acs_dashboards && python setup.py install)
(. ${VENV3}/bin/activate && cd ${WS}/other_src/arbiter && python setup.py install)
(. ${VENV3}/bin/activate && cd ${WS}/other_src/mavlink/pymavlink && python setup.py install)
(. ${VENV3}/bin/activate && cd ${WS}/src/autonomy-payload/ap_lib && python setup.py install)
(. ${VENV3}/bin/activate && cd ${WS}/other_src/swarmcommander && python setup.py install)

echo "Installing Game Director and dependencies"

GDI_VENV=${INSTALL_SPACE}/ugdi_venv
mkdir -p ${GDI_VENV}
virtualenv --system-site-packages ${GDI_VENV}
(. ${GDI_VENV}/bin/activate && cd ${WS}/other_src/ugdi && pip install -r requirements.txt )
(. ${GDI_VENV}/bin/activate && cd ${WS}/src/autonomy-payload/ap_lib && python setup.py install)
cp -r ${WS}/other_src/ugdi ${GDI_VENV}